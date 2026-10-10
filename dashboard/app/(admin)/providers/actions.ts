"use server";
import { supabaseServer } from "@/lib/supabase/server";
import { done, rpcError, str, optStr, bool, num } from "@/lib/act";

export async function reviewProvider(form: FormData) {
  const id = str(form, "id");
  const supabase = await supabaseServer();
  const result = await supabase.rpc("admin_review_provider", {
    p_provider: id, p_status: str(form, "status"), p_note: optStr(form, "note"), p_verified: bool(form, "verified"),
  });
  done(`/providers/${id}`, rpcError(result));
}

export async function setServiceStatus(form: FormData) {
  const supabase = await supabaseServer();
  const result = await supabase.rpc("admin_set_service_status", {
    p_service: str(form, "service"), p_status: str(form, "status"), p_note: optStr(form, "note"),
  });
  done(str(form, "back") || "/providers", rpcError(result));
}

export async function grantSubscription(form: FormData) {
  const id = str(form, "id");
  const supabase = await supabaseServer();
  const result = await supabase.rpc("admin_grant_subscription", {
    p_provider: id, p_plan: str(form, "plan"), p_months: num(form, "months"), p_note: optStr(form, "note"),
  });
  done(`/providers/${id}`, rpcError(result), "تمت إضافة المدة");
}
