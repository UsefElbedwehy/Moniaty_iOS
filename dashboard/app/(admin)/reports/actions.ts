"use server";
import { supabaseServer } from "@/lib/supabase/server";
import { done, rpcError, str, optStr } from "@/lib/act";

export async function resolveReport(form: FormData) {
  const supabase = await supabaseServer();
  const result = await supabase.rpc("admin_resolve_report", {
    p_report: str(form, "id"), p_status: str(form, "status"), p_note: optStr(form, "note"),
  });
  done("/reports", rpcError(result));
}
