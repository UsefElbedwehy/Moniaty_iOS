// Sends a real push notification via Firebase Cloud Messaging (HTTP v1) whenever a row is
// inserted into `public.notifications` — wired up as a Supabase Database Webhook (Database →
// Webhooks → Insert on `notifications` → this function's URL), NOT as a Postgres trigger, so no
// secret ever needs to live in a SQL migration file.
//
// Deliberately dependency-free: the OAuth2 token exchange for the Firebase service account is
// hand-rolled with the platform's Web Crypto API (RS256-sign a JWT, trade it for an access token)
// rather than pulling in a Google auth library, since npm-on-Deno compatibility for
// crypto-heavy packages has historically been a rough edge in edge runtimes.
//
// Required secrets (`supabase secrets set …`), see supabase/README.md:
//   FIREBASE_PROJECT_ID          - the Firebase project id pushes are sent from
//   FIREBASE_SERVICE_ACCOUNT_JSON - full JSON key for a service account with the
//                                   "Firebase Cloud Messaging API Admin" role
//   PUSH_WEBHOOK_SECRET          - random string; must match the `x-webhook-secret` header
//                                   configured on the Database Webhook
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are already injected automatically by the platform.

const FIREBASE_PROJECT_ID = Deno.env.get("FIREBASE_PROJECT_ID") ?? "";
const FIREBASE_SERVICE_ACCOUNT_JSON = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const PUSH_WEBHOOK_SECRET = Deno.env.get("PUSH_WEBHOOK_SECRET") ?? "";

interface ServiceAccount {
  client_email: string;
  private_key: string;
}

interface NotificationRecord {
  id: string;
  user_id: string | null;
  audience: string | null;
  kind: string;
  title: string;
  subtitle: string | null;
  body: string;
  image_url: string | null;
  /** Where a tap lands, e.g. https://munyati.co/b/<booking id>. Parsed by the app's DeepLink. */
  deep_link: string | null;
}

// Cached across warm invocations of the same function instance — avoids re-signing a JWT and
// round-tripping to Google's token endpoint on every single notification.
let cachedAccessToken: { token: string; expiresAt: number } | null = null;

function base64url(bytes: Uint8Array | string): string {
  const raw = typeof bytes === "string" ? bytes : String.fromCharCode(...bytes);
  return btoa(raw).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function getAccessToken(serviceAccount: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedAccessToken && cachedAccessToken.expiresAt > now + 60) {
    return cachedAccessToken.token;
  }

  const header = { alg: "RS256", typ: "JWT" };
  const claim = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };
  const unsigned = `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(claim))}`;

  const pemBody = serviceAccount.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");
  const keyBytes = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    keyBytes,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signatureBytes = new Uint8Array(
    await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(unsigned)),
  );
  const jwt = `${unsigned}.${base64url(signatureBytes)}`;

  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!tokenRes.ok) {
    throw new Error(`Google token exchange failed (${tokenRes.status}): ${await tokenRes.text()}`);
  }
  const { access_token, expires_in } = await tokenRes.json();
  cachedAccessToken = { token: access_token, expiresAt: now + (expires_in ?? 3600) };
  return access_token;
}

async function fetchDeviceTokens(userId: string): Promise<string[]> {
  const res = await fetch(
    `${SUPABASE_URL}/rest/v1/device_tokens?user_id=eq.${userId}&select=token`,
    {
      headers: {
        apikey: SUPABASE_SERVICE_ROLE_KEY,
        Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
      },
    },
  );
  if (!res.ok) throw new Error(`Failed to fetch device tokens (${res.status}): ${await res.text()}`);
  const rows: { token: string }[] = await res.json();
  return rows.map((r) => r.token);
}

// Every admin's device tokens — an admin-audience notification (null user_id) fans out to all
// admins' phones. Backed by the `admin_device_tokens()` RPC (service-role only).
async function fetchAdminDeviceTokens(): Promise<string[]> {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/admin_device_tokens`, {
    method: "POST",
    headers: {
      apikey: SUPABASE_SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
      "Content-Type": "application/json",
    },
    body: "{}",
  });
  if (!res.ok) throw new Error(`Failed to fetch admin device tokens (${res.status}): ${await res.text()}`);
  const rows: { token: string }[] = await res.json();
  return rows.map((r) => r.token);
}

async function deleteDeviceTokens(tokens: string[]): Promise<void> {
  if (tokens.length === 0) return;
  const filter = tokens.map((t) => `"${t}"`).join(",");
  await fetch(`${SUPABASE_URL}/rest/v1/device_tokens?token=in.(${filter})`, {
    method: "DELETE",
    headers: {
      apikey: SUPABASE_SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
    },
  });
}

async function sendToToken(accessToken: string, deviceToken: string, record: NotificationRecord) {
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token: deviceToken,
          notification: {
            title: record.title,
            body: record.body,
            ...(record.image_url ? { image: record.image_url } : {}),
          },
          data: {
            kind: record.kind,
            notification_id: record.id,
            ...(record.deep_link ? { deep_link: record.deep_link } : {}),
            // The Notification Service Extension reads `image` from data to attach a rich image,
            // and shows `subtitle` on the banner (aps.alert.subtitle below only covers the title/
            // body split, so the subtitle also rides in data for the extension to render).
            ...(record.image_url ? { image: record.image_url } : {}),
            ...(record.subtitle ? { subtitle: record.subtitle } : {}),
          },
          apns: {
            payload: {
              aps: {
                // `mutable-content` lets the NSE intercept & attach the downloaded image.
                "mutable-content": 1,
                sound: "default",
                alert: {
                  title: record.title,
                  ...(record.subtitle ? { subtitle: record.subtitle } : {}),
                  body: record.body,
                },
              },
            },
          },
        },
      }),
    },
  );
  if (res.ok) return { token: deviceToken, stale: false };

  const body = await res.json().catch(() => null);
  const errorCode = body?.error?.details?.find((d: { errorCode?: string }) => d.errorCode)?.errorCode;
  const stale = errorCode === "UNREGISTERED" || errorCode === "INVALID_ARGUMENT";
  if (!stale) {
    console.error(`FCM send failed for a token (${res.status}): ${JSON.stringify(body)}`);
  }
  return { token: deviceToken, stale };
}

Deno.serve(async (req) => {
  if (req.headers.get("x-webhook-secret") !== PUSH_WEBHOOK_SECRET) {
    return new Response("unauthorized", { status: 401 });
  }
  if (!FIREBASE_PROJECT_ID || !FIREBASE_SERVICE_ACCOUNT_JSON || !PUSH_WEBHOOK_SECRET) {
    console.error("send-push is missing required secrets — see this file's header comment.");
    return new Response("misconfigured", { status: 500 });
  }

  let payload: { type?: string; record?: NotificationRecord };
  try {
    payload = await req.json();
  } catch {
    return new Response("bad request", { status: 400 });
  }

  const record = payload.record;
  if (payload.type !== "INSERT" || !record) {
    return new Response("ignored", { status: 200 });
  }

  try {
    // Admin-audience rows carry no user_id — they fan out to every admin's device instead.
    const tokens = record.audience === "admin"
      ? await fetchAdminDeviceTokens()
      : record.user_id
        ? await fetchDeviceTokens(record.user_id)
        : [];
    if (tokens.length === 0) return new Response("no devices", { status: 200 });

    const serviceAccount: ServiceAccount = JSON.parse(FIREBASE_SERVICE_ACCOUNT_JSON);
    const accessToken = await getAccessToken(serviceAccount);

    const results = await Promise.all(tokens.map((t) => sendToToken(accessToken, t, record)));
    const staleTokens = results.filter((r) => r.stale).map((r) => r.token);
    await deleteDeviceTokens(staleTokens);

    return new Response("ok", { status: 200 });
  } catch (error) {
    console.error(`send-push failed: ${error instanceof Error ? error.message : String(error)}`);
    return new Response("internal error", { status: 500 });
  }
});
