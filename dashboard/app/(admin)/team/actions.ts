"use server";
import { supabaseServer } from "@/lib/supabase/server";
import { done, rpcError, str, bool } from "@/lib/act";

export async function addAdmin(form: FormData) {
  const supabase = await supabaseServer();
  const result = await supabase.rpc("admin_add_admin", { p_email: str(form, "email"), p_role: str(form, "role") });
  const err = rpcError(result);
  done("/team", err?.message === "no_auth_user" ? { message: "أضيفي هذا البريد أولاً من Supabase ← Authentication ← Invite user" } : err);
}

export async function setActive(form: FormData) {
  const supabase = await supabaseServer();
  const result = await supabase.rpc("admin_set_admin_active", { p_user: str(form, "user"), p_active: bool(form, "active") });
  done("/team", rpcError(result));
}
