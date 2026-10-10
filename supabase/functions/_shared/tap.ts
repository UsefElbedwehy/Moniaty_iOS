// Tap Payments helpers (hosted checkout). Every Tap call happens on the server with the secret
// key; a charge's status is always re-fetched from Tap, never taken from a request body.
// Env: TAP_SECRET_KEY (sk_test_… / sk_live_…), TAP_API_BASE (default https://api.tap.company).
import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import { requireEnv } from "./http.ts";

export interface TapCharge {
  id: string;
  status?: string;
  amount?: number;
  currency?: string;
  transaction?: { url?: string };
  metadata?: Record<string, string>;
  errors?: { description?: string }[];
}

function tapBase(): string {
  return Deno.env.get("TAP_API_BASE") || "https://api.tap.company";
}

export async function createCharge(body: Record<string, unknown>): Promise<TapCharge> {
  const res = await fetch(`${tapBase()}/v2/charges`, {
    method: "POST",
    headers: { Authorization: `Bearer ${requireEnv("TAP_SECRET_KEY")}`, "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  const charge = await res.json() as TapCharge;
  if (!res.ok) throw new Error(charge?.errors?.[0]?.description || `tap ${res.status}`);
  return charge;
}

export async function fetchCharge(id: string): Promise<TapCharge> {
  const res = await fetch(`${tapBase()}/v2/charges/${encodeURIComponent(id)}`, {
    headers: { Authorization: `Bearer ${requireEnv("TAP_SECRET_KEY")}` },
  });
  if (!res.ok) throw new Error(`tap ${res.status}`);
  return await res.json() as TapCharge;
}

/** Re-fetches the charge from Tap and applies it (idempotent). Returns our payment status. */
export async function settleCharge(admin: SupabaseClient, chargeId: string): Promise<string> {
  const charge = await fetchCharge(chargeId);
  const { data, error } = await admin.rpc("settle_subscription_payment", {
    p_charge_id: charge.id,
    p_status: charge.status ?? "",
    p_amount: charge.amount ?? null,
    p_currency: charge.currency ?? null,
    p_raw: charge,
  });
  if (error) throw error;
  return (data as { status?: string })?.status ?? "unknown";
}

/** Tap's { country_code, number } for a Saudi mobile stored as +9665XXXXXXXX. */
export function tapPhone(phone?: string | null): { country_code: string; number: string } | undefined {
  const digits = (phone ?? "").replace(/\D/g, "");
  return digits.startsWith("966") && digits.length === 12
    ? { country_code: "966", number: digits.slice(3) }
    : undefined;
}
