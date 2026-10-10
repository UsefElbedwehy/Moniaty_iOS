"use server";
import { supabaseServer } from "@/lib/supabase/server";
import { done, rpcError, str, optStr, bool } from "@/lib/act";

export async function moderateReview(form: FormData) {
  const supabase = await supabaseServer();
  const result = await supabase.rpc("admin_moderate_review", {
    p_review: str(form, "id"), p_status: str(form, "status"), p_note: optStr(form, "note"),
  });
  done(`/reviews?status=${str(form, "back") || "pending"}`, rpcError(result));
}

export async function setBan(form: FormData) {
  const supabase = await supabaseServer();
  const result = await supabase.rpc("admin_set_review_ban", { p_user: str(form, "user"), p_banned: bool(form, "banned") });
  done(str(form, "back_path") || "/users", rpcError(result));
}
