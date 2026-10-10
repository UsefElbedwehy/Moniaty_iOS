"use server";
import { supabaseServer } from "@/lib/supabase/server";
import { done, rpcError, str, optStr } from "@/lib/act";

export async function sendCampaign(form: FormData) {
  const supabase = await supabaseServer();
  const cities = form.getAll("cities").map(String).filter(Boolean);
  const result = await supabase.rpc("admin_send_campaign", {
    p_audience: str(form, "audience"), p_city_ids: cities, p_title: str(form, "title"), p_body: str(form, "body"),
    p_deep_link: optStr(form, "deep_link"),
  });
  const reached = (result.data as { recipients?: number } | null)?.recipients ?? 0;
  done("/push", rpcError(result), `تم الإرسال إلى ${reached} مستخدم`);
}
