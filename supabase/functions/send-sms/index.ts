// send-sms: Database Webhook on INSERT into `public.sms_outbox` → one transactional SMS by
// OurSMS (booking approved, receipt uploaded, payment confirmed, reminders…). Which events send
// SMS is controlled from the dashboard (`app_config.sms_events`); the queueing happens in SQL.
// Secrets: SMS_WEBHOOK_SECRET (also set as the webhook's x-webhook-secret header),
// OURSMS_API_KEY, OURSMS_SENDER.
import { createClient } from "npm:@supabase/supabase-js@2";
import { json, requireEnv } from "../_shared/http.ts";
import { sendSms } from "../_shared/sms.ts";

interface OutboxRecord {
  id: number;
  phone: string;
  body: string;
  purpose: string;
}

Deno.serve(async (req) => {
  if (req.headers.get("x-webhook-secret") !== requireEnv("SMS_WEBHOOK_SECRET")) {
    return new Response("unauthorized", { status: 401 });
  }
  const payload: { type?: string; record?: OutboxRecord } = await req.json().catch(() => ({}));
  const record = payload.record;
  if (payload.type !== "INSERT" || !record) return json(200, { ignored: true });

  try {
    const admin = createClient(requireEnv("SUPABASE_URL"), requireEnv("SUPABASE_SERVICE_ROLE_KEY"), {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const result = await sendSms(admin, record.phone, record.body, "transactional", record.purpose);
    if (result.ok) await admin.from("sms_outbox").delete().eq("id", record.id);
    return json(200, { ok: result.ok });
  } catch (error) {
    console.error("send-sms failed:", error instanceof Error ? error.message : error);
    return json(500, { error: "internal" });
  }
});
