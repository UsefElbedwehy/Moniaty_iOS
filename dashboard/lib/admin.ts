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

export function can(admin: Admin, permission: string): boolean {
  return admin.roleId === "owner" || admin.permissions.has(permission);
}
