import { redirect } from "next/navigation";
import { supabaseServer } from "./supabase/server";

export type Admin = {
  userId: string;
  email: string | null;
  roleId: string;
  permissions: Set<string>;
};

/** The signed-in admin, or a redirect to /login. Owners have every permission. */
export async function requireAdmin(): Promise<Admin> {
  const supabase = await supabaseServer();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login");
  const { data: row } = await supabase.from("admin_users").select("role_id, is_active").eq("user_id", user.id).maybeSingle();
  if (!row || !row.is_active) redirect("/login?error=not_admin");
  const { data: perms } = await supabase.from("admin_role_permissions").select("permission").eq("role_id", row.role_id);
  return {
    userId: user.id,
    email: user.email ?? null,
    roleId: row.role_id,
    permissions: new Set((perms ?? []).map((p) => p.permission as string)),
  };
}

/**
 * Mirrors `has_admin_permission()`: the developer has everything; the audit log is developer-only;
 * otherwise owners have everything and other roles their own list.
 */
export function can(admin: Admin, permission: string): boolean {
  if (admin.roleId === "developer") return true;
  if (permission === "audit.read") return false;
  return admin.roleId === "owner" || admin.permissions.has(permission);
}

/** Raw JSON views and editors are for the developer only. */
export async function isDeveloper(): Promise<boolean> {
  return (await requireAdmin()).roleId === "developer";
}

/** Owners (and the developer) alone can delete records permanently. */
export async function isOwner(): Promise<boolean> {
  const { roleId } = await requireAdmin();
  return roleId === "owner" || roleId === "developer";
}
