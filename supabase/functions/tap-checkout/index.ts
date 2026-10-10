// tap-checkout: provider plan payments through Tap's hosted page (decision #2).
//   { "plan_id": "plus" }     → { payment_id, url }   open `url` in ASWebAuthenticationSession
//   { "payment_id": "…" }     → { status }            initiated | captured | failed | review
// The amount comes from `subscription_plans` (start_subscription_payment), never the client.
// When a payment is still open, its status is re-fetched from Tap and settled, so the app gets
// the outcome even if the webhook is late.
// Env: TAP_SECRET_KEY, TAP_API_BASE (optional), SUPABASE_URL / SUPABASE_ANON_KEY /
//      SUPABASE_SERVICE_ROLE_KEY (provided by Supabase).
import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders, json, requireEnv } from "../_shared/http.ts";
import { createCharge, settleCharge, tapPhone } from "../_shared/tap.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json(405, { error: "method not allowed" });

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) return json(401, { error: "missing bearer token" });

  let body: { plan_id?: string; payment_id?: string };
  try {
    body = await req.json();
  } catch {
    return json(400, { error: "bad request" });
  }

  const supabaseUrl = requireEnv("SUPABASE_URL");
  const userClient = createClient(supabaseUrl, requireEnv("SUPABASE_ANON_KEY"), {
    global: { headers: { Authorization: authHeader } },
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const admin = createClient(supabaseUrl, requireEnv("SUPABASE_SERVICE_ROLE_KEY"), {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: { user } } = await userClient.auth.getUser();
  if (!user) return json(401, { error: "invalid token" });

  try {
    // Status of an existing payment (only the caller's own: the RPC filters by auth.uid()).
    if (body.payment_id) {
      const { data, error } = await userClient.rpc("get_my_subscription_payment", { p_id: body.payment_id });
      if (error) throw error;
      const payment = data as { status: string; tap_charge_id: string | null } | null;
      if (!payment) return json(404, { error: "not found" });
      if (payment.status === "initiated" && payment.tap_charge_id) {
        return json(200, { status: await settleCharge(admin, payment.tap_charge_id) });
      }
      return json(200, { status: payment.status });
    }

    if (!body.plan_id) return json(400, { error: "plan_id required" });
    const { data: started, error: startError } = await userClient.rpc("start_subscription_payment", { p_plan: body.plan_id });
    if (startError) throw startError;
    const payment = started as {
      ok: boolean; error?: string; id: string; amount: number; currency: string; plan_name: string;
      business_name: string | null; phone: string | null;
    };
    if (!payment.ok) return json(200, { error: payment.error });

    const charge = await createCharge({
      amount: payment.amount,
      currency: payment.currency,
      customer_initiated: true,
      threeDSecure: true,
      save_card: false,
      description: `Munyati ${payment.plan_name}`,
      metadata: { payment_id: payment.id, provider_id: user.id, plan_id: body.plan_id },
      reference: { transaction: payment.id, order: payment.id },
      receipt: { email: false, sms: true },
      customer: {
        first_name: (payment.business_name || "Munyati").slice(0, 40),
        last_name: "provider",
        phone: tapPhone(payment.phone),
      },
      source: { id: "src_all" },
      post: { url: `${supabaseUrl}/functions/v1/tap-webhook` },
      redirect: { url: `${supabaseUrl}/functions/v1/tap-webhook` },
    });
    const url = charge.transaction?.url;
    if (!charge.id || !url) throw new Error("no payment url");

    const { error: attachError } = await admin.rpc("attach_tap_charge", { p_payment: payment.id, p_charge_id: charge.id });
    if (attachError) throw attachError;
    return json(200, { payment_id: payment.id, url });
  } catch (error) {
    console.error(`tap-checkout failed for ${user.id}:`, error instanceof Error ? error.message : error);
    return json(502, { error: "payment gateway error" });
  }
});
