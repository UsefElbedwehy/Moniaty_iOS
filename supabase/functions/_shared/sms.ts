// One OurSMS client for OTP, booking updates and (later) marketing campaigns.
// API: POST https://api.oursms.com/msgs/sms with a Bearer key (docs/research/oursms.md).
import { SupabaseClient } from "npm:@supabase/supabase-js@2";
import { requireEnv } from "./http.ts";

export type SmsKind = "otp" | "transactional" | "promotional";

export interface SmsResult {
  ok: boolean;
  /** Arabic, user-safe message when not ok. Provider details stay in the logs. */
  error?: string;
}

/** Sends one SMS and records it in `sms_log` (for cost and delivery reporting). */
export async function sendSms(
  admin: SupabaseClient,
  to: string,
  body: string,
  kind: SmsKind,
  purpose: string,
): Promise<SmsResult> {
  const apiKey = requireEnv("OURSMS_API_KEY");
  // Promotional traffic must use the separately registered "-AD" sender name.
  const sender = kind === "promotional" ? requireEnv("OURSMS_SENDER_AD") : requireEnv("OURSMS_SENDER");

  const response = await fetch("https://api.oursms.com/msgs/sms", {
    method: "POST",
    headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      src: sender,
      dests: [to],
      body,
      msgClass: kind === "promotional" ? "promotional" : "transactional",
      priority: kind === "otp" ? 1 : 0,
      validity: kind === "otp" ? 10 : 1440,
      maxParts: kind === "otp" ? 1 : 3,
    }),
  });
  const text = await response.text();
  const segments = Math.max(1, Math.ceil(body.length / 70)); // Arabic is UCS-2: 70 chars per part

  await admin.from("sms_log").insert({
    phone: to,
    kind,
    purpose,
    segments,
    status: response.ok ? "sent" : "failed",
    provider_status: response.status,
    provider_response: text.slice(0, 1000),
  });

  if (response.ok) return { ok: true };
  console.error(`OurSMS rejected (${response.status}): ${text}`);
  if (text.includes("6307") || text.includes("Source address not allowed")) {
    return { ok: false, error: "تعذّر إرسال الرسالة حالياً، حاولي لاحقاً" }; // sender not approved yet
  }
  if (text.includes("1008") || text.includes("Insufficient balance")) {
    return { ok: false, error: "تعذّر إرسال الرسالة حالياً، حاولي لاحقاً" };
  }
  return { ok: false, error: "فشل إرسال الرسالة، حاولي مرة أخرى" };
}
