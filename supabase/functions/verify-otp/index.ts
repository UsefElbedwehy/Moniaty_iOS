// verify-otp: checks a login code and returns a Supabase session.
//
// - Existing number: signs straight in.
// - New number without a name: returns { requires_registration: true } (the code stays valid).
// - New number with first/last name and role ("bride" | "provider"): creates the account.
//   A provider gets a `providers` row in status "pending" (admin approval) via a DB trigger.
//
// Each phone maps to a synthetic email account whose password is derived from PASSWORD_SECRET,
// so GoTrue issues normal access/refresh tokens.
// Secrets: OTP_HASH_SECRET, PASSWORD_SECRET, (optional) DEV_PHONES + DEV_OTP_CODE.
import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders, json, requireEnv } from "../_shared/http.ts";
import { normalizeSaudiMobile } from "../_shared/phone.ts";
import { derivePassword, devBypass, hashOTP } from "../_shared/otp.ts";

interface RequestBody {
  phone?: string;
  code?: string;
  first_name?: string;
  last_name?: string;
  role?: string;
}

const CHECK_MESSAGES: Record<string, [number, string]> = {
  invalid: [401, "الرمز غير صحيح أو انتهت صلاحيته"],
  expired: [401, "الرمز غير صحيح أو انتهت صلاحيته"],
  locked: [429, "تجاوزتِ عدد المحاولات. اطلبي رمزاً جديداً"],
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders });
  try {
    const body: RequestBody = await req.json().catch(() => ({}));
    const phone = typeof body.phone === "string" ? normalizeSaudiMobile(body.phone) : null;
    const code = (body.code ?? "").trim();
    if (!phone || !/^\d{6}$/.test(code)) return json(400, { error: "رقم الجوال والرمز مطلوبان" });

    const supabaseUrl = requireEnv("SUPABASE_URL");
    const admin = createClient(supabaseUrl, requireEnv("SUPABASE_SERVICE_ROLE_KEY"), {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    // 1. Check the code (attempt counting is atomic in SQL).
    if (!devBypass(phone, code)) {
      const { data: status, error } = await admin.rpc("otp_check", {
        p_phone: phone,
        p_code_hash: await hashOTP(phone, code, requireEnv("OTP_HASH_SECRET")),
      });
      if (error) throw error;
      if (status !== "ok") {
        const [httpStatus, message] = CHECK_MESSAGES[status] ?? CHECK_MESSAGES.invalid;
        return json(httpStatus, { error: message });
      }
    }

    // 2. Find or create the account.
    const email = `${phone.replace("+", "")}@phone.munyati.co`;
    const password = await derivePassword(phone, requireEnv("PASSWORD_SECRET"));
    const { data: existing } = await admin
      .from("profiles").select("id, role").eq("phone", phone).is("deleted_at", null).maybeSingle();

    let userId: string;
    let role: string | null = existing?.role ?? null;
    if (existing) {
      userId = existing.id;
    } else {
      const first = (body.first_name ?? "").trim();
      const last = (body.last_name ?? "").trim();
      if (!first || !last) return json(200, { requires_registration: true });
      role = body.role === "provider" ? "provider" : "bride";
      const displayName = `${first} ${last}`;

      const { data: created, error: createError } = await admin.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: { phone, display_name: displayName, role },
      });
      if (createError) {
        // An auth user without a profile (e.g. a profile insert failed earlier): reuse it.
        const { data: orphanId } = await admin.rpc("auth_user_id_for_email", { p_email: email });
        if (!orphanId) throw createError;
        userId = orphanId;
        await admin.auth.admin.updateUserById(userId, { password });
      } else {
        userId = created.user!.id;
      }
      const { error: profileError } = await admin.from("profiles").upsert(
        { id: userId, phone, first_name: first, last_name: last, display_name: displayName, role },
        { onConflict: "id" },
      );
      if (profileError) throw profileError;
    }

    // 3. Mint a normal session.
    const anon = createClient(supabaseUrl, requireEnv("SUPABASE_ANON_KEY"), {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { data: signIn, error: signInError } = await anon.auth.signInWithPassword({ email, password });
    if (signInError || !signIn.session) throw signInError ?? new Error("no session");

    // 4. Burn the code only once the session exists.
    await admin.rpc("otp_consume", { p_phone: phone });

    return json(200, {
      success: true,
      access_token: signIn.session.access_token,
      refresh_token: signIn.session.refresh_token,
      expires_in: signIn.session.expires_in,
      user: { id: userId, phone },
      role,
    });
  } catch (error) {
    console.error("verify-otp error:", error instanceof Error ? error.message : error);
    return json(500, { error: "حدث خطأ، حاولي مرة أخرى" });
  }
});
