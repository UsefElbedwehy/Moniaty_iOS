// send-otp: issues a 6-digit login code by SMS (OurSMS).
// Rate limits (cooldown, per-phone hourly/daily caps, per-IP cap, global breaker) are enforced
// atomically inside the `otp_issue` SQL function, so parallel requests cannot race past them.
// Secrets: OTP_HASH_SECRET, OURSMS_API_KEY, OURSMS_SENDER, (optional) DEV_PHONES + DEV_OTP_CODE.
import { createClient } from "npm:@supabase/supabase-js@2";
import { clientIp, json, corsHeaders, requireEnv } from "../_shared/http.ts";
import { normalizeSaudiMobile } from "../_shared/phone.ts";
import { generateOTP, hashOTP } from "../_shared/otp.ts";
import { sendSms } from "../_shared/sms.ts";

const LIMIT_MESSAGES: Record<string, string> = {
  cooldown: "يمكنك طلب رمز جديد بعد قليل",
  hourly: "تجاوزتِ عدد المحاولات المسموح بها. حاولي بعد ساعة",
  daily: "تجاوزتِ عدد المحاولات المسموح بها اليوم. حاولي غداً",
  ip: "طلبات كثيرة من هذا الجهاز. حاولي لاحقاً",
  busy: "الخدمة مشغولة حالياً. حاولي بعد دقائق",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders });
  try {
    const { phone } = await req.json().catch(() => ({}));
    const normalized = typeof phone === "string" ? normalizeSaudiMobile(phone) : null;
    if (!normalized) return json(400, { error: "أدخلي رقم جوال سعودي صحيح يبدأ بـ 5" });

    const admin = createClient(requireEnv("SUPABASE_URL"), requireEnv("SUPABASE_SERVICE_ROLE_KEY"), {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const secret = requireEnv("OTP_HASH_SECRET");

    // Test numbers get a fixed code and no SMS (see _shared/otp.ts devBypass).
    const devPhones = (Deno.env.get("DEV_PHONES") ?? "").split(",").map((s) => s.trim());
    const devCode = Deno.env.get("DEV_OTP_CODE") ?? "";
    const isDev = devCode.length === 6 && devPhones.includes(normalized);

    const code = isDev ? devCode : generateOTP();
    const { data: issued, error } = await admin.rpc("otp_issue", {
      p_phone: normalized,
      p_ip: clientIp(req),
      p_code_hash: await hashOTP(normalized, code, secret),
    });
    if (error) throw error;
    if (!issued?.ok) {
      return json(429, { error: LIMIT_MESSAGES[issued?.error] ?? LIMIT_MESSAGES.busy, retry_after: issued?.retry_after });
    }
    if (isDev) return json(200, { success: true });

    const sms = await sendSms(
      admin,
      normalized,
      `منيتي: رمز التحقق ${code}\nصالح لمدة 10 دقائق. لا تشاركيه مع أحد.`,
      "otp",
      "login",
    );
    if (!sms.ok) return json(502, { error: sms.error });
    return json(200, { success: true });
  } catch (error) {
    console.error("send-otp error:", error instanceof Error ? error.message : error);
    return json(500, { error: "حدث خطأ، حاولي مرة أخرى" });
  }
});
