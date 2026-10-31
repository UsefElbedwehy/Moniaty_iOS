// verify-otp: checks a login code and returns a Supabase session.
//
// One phone may hold two accounts: a bride account and a provider account. `role` is the side
// picked on the sign-in screen.
// - The number has an account for that side: signs straight in. (No `role`, from an older app:
//   the number's oldest account.)
// - It has none yet, without a name: returns { requires_registration: true, other_role } (the
//   code stays valid; other_role tells the app the number already has the other kind).
// - It has none yet, with first/last name: creates the account for that side (a customer account
//   keeps `audience`, «عروس» or «معازيم», from the sign-in screen). A provider gets a
//   `providers` row in status "pending" (admin approval) via a DB trigger. A number whose other
//   account is banned can't open a second one.
//
// Each account is a synthetic email user whose password is derived from PASSWORD_SECRET, so
// GoTrue issues normal access/refresh tokens. The first account on a number uses
// <digits>@phone.munyati.co; the second <digits>.<role>@phone.munyati.co.
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
  audience?: string;
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

    // 2. Find or create the account for the chosen side.
    const digits = phone.replace("+", "");
    const password = await derivePassword(phone, requireEnv("PASSWORD_SECRET"));
    const wanted = body.role === "provider" ? "provider" : body.role === "bride" ? "bride" : null;
    const { data: accounts, error: lookupError } = await admin
      .from("profiles").select("id, role, is_banned, created_at").eq("phone", phone).is("deleted_at", null)
      .order("created_at");
    if (lookupError) throw lookupError;
    const existing = wanted ? accounts?.find((a) => a.role === wanted) : accounts?.[0];

    let userId: string;
    let role: string;
    let email: string;
    if (existing) {
      userId = existing.id;
      role = existing.role;
      const { data: authUser, error: authError } = await admin.auth.admin.getUserById(userId);
      if (authError || !authUser.user?.email) throw authError ?? new Error("account has no email");
      email = authUser.user.email;
    } else {
      role = wanted ?? "bride";
      const other = accounts?.find((a) => a.role !== role);
      const first = (body.first_name ?? "").trim();
      const last = (body.last_name ?? "").trim();
      if (!first || !last) return json(200, { requires_registration: true, other_role: other?.role ?? null });
      if (other?.is_banned) return json(403, { error: "لا يمكن إنشاء حساب جديد بهذا الرقم. تواصلي مع الدعم" });
      const displayName = `${first} ${last}`;
      const audience = role === "bride" && (body.audience === "guests" || body.audience === "both")
        ? body.audience : "bride";

      // The first free address: an auth user that already has a live profile belongs to the
      // other account and must never be reused; one without a profile is an orphan from a failed
      // sign-up and is taken over.
      email = "";
      let orphanId: string | null = null;
      for (const candidate of [`${digits}@phone.munyati.co`, `${digits}.${role}@phone.munyati.co`]) {
        const { data: ownerId } = await admin.rpc("auth_user_id_for_email", { p_email: candidate });
        if (!ownerId) { email = candidate; break; }
        const { data: profile } = await admin.from("profiles").select("id").eq("id", ownerId).maybeSingle();
        if (!profile) { email = candidate; orphanId = ownerId; break; }
      }
      if (!email) throw new Error("no free account address for this number");

      if (orphanId) {
        userId = orphanId;
        await admin.auth.admin.updateUserById(userId, { password, user_metadata: { phone, display_name: displayName, role } });
      } else {
        const { data: created, error: createError } = await admin.auth.admin.createUser({
          email,
          password,
          email_confirm: true,
          user_metadata: { phone, display_name: displayName, role },
        });
        if (createError) throw createError;
        userId = created.user!.id;
      }
      const { error: profileError } = await admin.from("profiles").insert(
        { id: userId, phone, first_name: first, last_name: last, display_name: displayName, role, audience },
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
