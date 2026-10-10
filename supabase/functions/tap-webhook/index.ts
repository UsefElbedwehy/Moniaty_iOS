// tap-webhook (deploy with verify_jwt = false; Tap and browsers can't send a user token).
//   POST: Tap's server-to-server notification. The body is not trusted: only the charge id is
//         taken from it, and the charge is re-fetched from Tap before anything changes.
//   GET:  Tap's browser redirect after payment (?tap_id=…). Settles the payment as a safety net
//         and bounces to munyati://pay-return, which closes the in-app browser sheet.
// Always answers 200 to Tap once handled, so it doesn't retry forever.
import { createClient } from "npm:@supabase/supabase-js@2";
import { requireEnv } from "../_shared/http.ts";
import { settleCharge } from "../_shared/tap.ts";

function adminClient() {
  return createClient(requireEnv("SUPABASE_URL"), requireEnv("SUPABASE_SERVICE_ROLE_KEY"), {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}

function returnPage(status: string, deepLink: string): Response {
  const ok = status === "captured";
  const title = ok ? "تم الدفع بنجاح" : "لم يكتمل الدفع";
  const message = ok ? "تم تفعيل باقتك. يمكنك العودة إلى التطبيق." : "ارجعي إلى التطبيق وحاولي مرة أخرى.";
  const html = `<!doctype html><html lang="ar" dir="rtl"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1"><title>منيتي — الدفع</title>
<style>body{margin:0;min-height:100vh;display:grid;place-items:center;background:#FAFAEC;color:#2B1B20;
font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}.c{max-width:420px;padding:32px 24px;text-align:center}
h1{font-size:20px;margin:0 0 8px;color:#8A0D3A}p{margin:0 0 22px;line-height:1.6}
a{display:inline-block;background:#8A0D3A;color:#FAFAEC;text-decoration:none;font-weight:600;padding:13px 22px;border-radius:14px}</style>
</head><body><div class="c"><h1>${title}</h1><p>${message}</p><a href="${deepLink}">العودة إلى منيتي</a></div>
<script>setTimeout(function(){location.href=${JSON.stringify(deepLink)}},400)</script></body></html>`;
  const headers = new Headers({ "Content-Type": "text/html; charset=utf-8", "Cache-Control": "no-store" });
  return new Response(new TextEncoder().encode(html), { status: 200, headers });
}

Deno.serve(async (req) => {
  if (req.method === "GET") {
    const tapId = new URL(req.url).searchParams.get("tap_id") ?? "";
    let status = "unknown";
    if (/^chg_[A-Za-z0-9]+$/.test(tapId)) {
      try {
        status = await settleCharge(adminClient(), tapId);
      } catch (error) {
        console.error("tap return settle failed:", error instanceof Error ? error.message : error);
      }
    }
    return returnPage(status, `munyati://pay-return?tap_id=${encodeURIComponent(tapId)}`);
  }
  if (req.method !== "POST") return new Response("ok", { status: 200 });

  let chargeId: string | undefined;
  try {
    const body = await req.json();
    chargeId = body?.id ?? body?.charge?.id;
  } catch { /* ignore */ }
  if (!chargeId || !/^chg_[A-Za-z0-9]+$/.test(chargeId)) return new Response("ok", { status: 200 });

  try {
    await settleCharge(adminClient(), chargeId);
    return new Response("ok", { status: 200 });
  } catch (error) {
    // Tap retries on non-2xx; a transient failure is worth a retry.
    console.error(`tap-webhook settle failed for ${chargeId}:`, error instanceof Error ? error.message : error);
    return new Response("retry", { status: 500 });
  }
});
