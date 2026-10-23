# OurSMS for Munyati: OTP, transactional SMS and dashboard marketing campaigns

Scope: research on the OurSMS gateway (API, sender names, pricing, limits), Saudi rules for SMS (sender IDs, marketing consent, sending hours), how the owner's existing apps already call OurSMS, and a concrete design for Munyati's `send-otp`/`verify-otp` Edge Functions and the admin "SMS marketing campaigns" feature.

> **How reliable the sources are.** In this sandbox, WebFetch could not resolve `oursms.com`, `oursms.net`, `oursms.app`, `bird.com`, `taqnyat.sa` or `support.telnyx.com` (`getaddrinfo ENOTFOUND`), and curl through the proxy was refused (`CONNECT 403`). Every claim about those sites below therefore comes from **search-engine summaries of the page**, not a direct read. Each claim is cited to the page it came from. GitHub pages and `pub.dev` could be fetched directly. The strongest evidence for the **current** API is the owner's own production code, which really sends OTPs through `https://api.oursms.com/msgs/sms` (section 2). No public page I could reach documents that exact endpoint.

---

## 0. Summary

- **OurSMS is already in production in both of the owner's apps.** Both call `POST https://api.oursms.com/msgs/sms` with `Authorization: Bearer <OURSMS_API_KEY>` and a JSON body `{src, dests[], body, msgClass, priority, validity, maxParts, ...}`. Munyati should **copy Kolna's version** (`kolna-al-khafji-ios/supabase/functions/send-otp` and `verify-otp`). It already does HMAC-hashed codes, a CSPRNG, a 10-minute expiry, a 5-attempt lockout, a 60 s cooldown, 5/hour and 10/day caps, and Arabic error mapping. **Do not copy Lamha's version**: it stores codes in plaintext, uses `Math.random`, has no attempt limit and leaks raw provider responses to the client.
- **Gaps to fix when porting:**
  1. Rate limiting and attempt counting are read-then-write, so parallel requests race past them. Move both into atomic Postgres functions.
  2. There is no per-IP limit and no global circuit breaker against SMS pumping.
  3. The country allowlist includes +965 and +20. Munyati should allow only Saudi mobiles (`+9665…`).
  4. `verify-otp` needs a `role` (`customer` | `provider`) for new accounts.
  5. Add a provider-agnostic `_shared/sms.ts` so marketing, OTP and transactional sends share one client and one log.
- **Public docs are thin.**
  - The only detailed public spec found is the older "API Document v1.0". It describes `POST https://api.oursms.com/api-a/msgs` with username/password, up to **500 destinations per request**, `priority` 1–4 (0 = auto), `delay`, `validity`, `maxParts`, `dlr`, `prevDups` and `msgClass`. There is also a credits endpoint, `api-a/billing/credits`.
  - The current developer platform advertises an SMS API, an OTP API, a WhatsApp API, webhooks for delivery reports, and API keys that can be **IP-restricted**.
  - No published rate limits, webhook schema, DLR status codes or response schema were found. **Ask OurSMS for the v2 (`/msgs/*`) reference** before building campaigns.
- **Sender names (KSA):**
  - The sender name needs a Commercial Registration (CR) and must relate to the CR or business activity. If it does not, supporting documents are required, for example **proof of owning a Saudi domain**. Note that `munyati.co` is not a `.sa` domain, so the CR must carry the name.
  - English sender names are max 11 characters. OurSMS states a max of 8 characters for **promotional** names.
  - Register **two** names: a transactional/OTP name (e.g. `Munyati`) and a promotional one with the `-AD` suffix (e.g. `Munyati-AD`).
- **Marketing rules (KSA):** these come from secondary sources and they disagree.
  - Explicit opt-in consent is required, plus an opt-out in every promotional message.
  - Promotional sending is restricted to daytime. The windows cited vary from 06:00–19:00 to 08:00–22:00 Riyadh time. **Default to 09:00–19:00 Asia/Riyadh** (inside every cited window) until OurSMS confirms.
  - URLs must be whitelisted and URL shorteners are not allowed.
  - PDPL requires documented consent and easy withdrawal.
- **Price:**
  - OurSMS's 2026 blog says packages run from SAR 130 per 1,000 SMS to SAR 6,900 per 100,000 SMS, VAT included. That is about SAR 0.13 to SAR 0.069 per SMS.
  - The older pricing page lists the same numbers labelled "halala", which is almost certainly a unit error. **Confirm the price with OurSMS sales.**
  - Arabic SMS are UCS-2, so 70 characters fit in one segment and 67 per segment when concatenated. Cost estimates must count segments.

---

## 1. OurSMS API: what could be verified

### 1.1 Two (really three) API generations

| Generation | Base / endpoint | Auth | Evidence |
|---|---|---|---|
| Legacy `oursms.net` | `www.OurSms.net/api/sendsms.php?username=…&password=…` | query-string credentials | [EngApi.pdf](https://oursms.net/files4Download/EngApi.pdf) (search summary) |
| "API Document v1.0" | `POST/GET https://api.oursms.com/api-a/msgs`, credits at `api-a/billing/credits` | `username` + `password` fields | [Oursmsupdatedapi.pdf](https://oursms.net/files4Download/Oursmsupdatedapi.pdf) (search summary) |
| Current (used by the owner) | `POST https://api.oursms.com/msgs/sms`, JSON | `Authorization: Bearer <API key>` | owner's production code (section 2); [limlifestyle PR #10](https://github.com/hassanhmostafa/limlifestyle/pull/10) also uses `/msgs/sms` and `OURSMS_API_KEY` |
| Unrelated `oursms.app` | `https://oursms.app/api/v1/SMS` + `/Add/SendOneSms`, `/Add/SendOtpSms`, `/Get/GetStatus/{id}` with `userId` + `key` in the body | body credentials | [munafio/oursms-laravel](https://github.com/munafio/oursms-laravel) ([src](https://github.com/munafio/oursms-laravel/blob/master/src/OurSMS.php)). Its README begins "The Service Has STOPPED!". See also [pub.dev oursms](https://pub.dev/documentation/oursms/latest/). **Do not use.** |

### 1.2 Request fields (v1.0 doc, the same names the owner's `/msgs/sms` calls use)

From the v1.0 document ([PDF](https://oursms.net/files4Download/Oursmsupdatedapi.pdf), via search summary):

| Field | Meaning |
|---|---|
| `src` | Sender name. Mandatory. Must be an approved sender. |
| `dests` | Recipients. Mandatory. One destination or up to **500 per request** (comma-separated in v1.0; a JSON array in the owner's `/msgs/sms` calls). |
| `body` | Text. Encoding is detected automatically. |
| `priority` | 1–4, where 1 is highest. 0 or unset lets a "smart algorithm" choose. |
| `delay` | Minutes to hold the message in the queue. 0 sends immediately. |
| `validity` | Validity window. The owner's code treats it as minutes. |
| `maxParts` | Max concatenated parts (not detailed in the snippet). |
| `dlr` | Delivery-report flag (not detailed in the snippet). |
| `prevDups` | Prevent duplicates (not detailed in the snippet). |
| `msgClass` | Routing class. The example uses `promotional`, and the list begins with `transactional` (the rest of the list was cut off). |

The owner's code also sends `transliteration: "AUTO"` (Lamha). I found no public documentation for it.

A [PR in another project](https://github.com/hassanhmostafa/limlifestyle/pull/10) reports two things. First, the `/msgs/sms` docs require `body` and do not document `templateId`. Second, OurSMS restricted that account to sending an **approved OTP text verbatim** (`رمز التحقق الخاص بك ( 0123 )`), and other wording got HTTP 400. **Implication for Munyati:** keep the OTP wording fixed and identical to whatever OurSMS approves, and keep it in one server-side constant.

### 1.3 Response format and error codes (not verified)

- I found no public response schema for `/msgs/sms`. Kolna only logs the raw response (`console.log("OurSMS response:", smsResponse.status, smsResponseText)`), so the repos do not reveal it either.
- **Action:** in staging, send one SMS, record the response JSON, and pin a typed parser. At minimum, keep the provider message id(s) for delivery tracking.
- The owner's code maps these error codes. They come from the code's own comments, not from public docs:
  - `6307` "Source address not allowed" means the sender name is not approved. Lamha's comment says this actually happened with sender `"Lamha"`.
  - `1001` means invalid credentials.
  - `1008` means insufficient balance.

### 1.4 Other platform facts

- The developer platform offers an SMS API, an OTP API and a WhatsApp API, plus "webhooks for receiving real-time delivery reports, message status updates, and event notifications". API keys are generated in the dashboard ([developers](https://oursms.com/en/developers-2/)). I could not find the OTP API's endpoint or parameters.
- Delivery reports are available "through the web control panel and through the APIs" ([features](https://oursms.com/en/documentation/getting-started/service-features/)).
- API keys are created under Developer → API Keys and can carry an optional **Access Restriction** to specific IP addresses ([api-key guide](https://oursms.com/en/documentation/developer-and-programmer/api-key-en/), [IP restriction](https://oursms.com/en/documentation/others-en/restrict-api-access-by-ip-address/)).
  - **Do not enable this for Supabase Edge Functions.** Supabase says Edge Functions cannot provide static egress IPs ([Supabase docs](https://supabase.com/docs/guides/troubleshooting/why-supabase-edge-functions-cannot-provide-static-egress-ips-for-whitelisting-3d78b0.md)). The only ways to IP-lock the key would be a fixed-IP proxy (e.g. QuotaGuard) or a separate worker.
- OurSMS's own guidance on webhooks: status callbacks can arrive out of order or more than once, so key them by message id plus timestamp and make the handlers idempotent ([WhatsApp fallback article](https://oursms.com/en/whatsapp-sms-fallback-how-to-keep-critical-messages-deliverable/)). It also recommends signature verification and rate limiting on the receiver ([webhook security](https://oursms.com/en/webhook-security-for-messaging-apis-oursms/)). The webhook payload and signature scheme are **not public**; ask OurSMS.
- **Rate limits:** I found no published figures.
- **Official SDKs:** none found. OurSMS says the API works from "any language" and has a PHP guide ([PHP guide](https://oursms.com/en/documentation/developer-and-programmer/sms-gateway-api-in-php/)). The Laravel and Dart packages found are community packages for the defunct `oursms.app` API. There is no Node or Deno SDK, and none is needed: a single `fetch` call is enough (section 3).

### 1.5 Pricing

| Package | Price (the 2026 blog's reading, SAR) | Per SMS |
|---|---|---|
| 1,000 | 130 | 0.130 |
| 5,000 | 500 | 0.100 |
| 10,000 | 900 | 0.090 |
| 50,000 | 3,700 | 0.074 |
| 100,000 | 6,900 | 0.069 |

- Sources: the [pricing page](https://oursms.com/en/pricing/) (labels these amounts "halala", says 15% VAT is included, and was last indexed about 963 days ago) and the [2026 blog](https://oursms.com/en/whatsapp-vs-sms-cost-in-saudi-arabia-2026-oursms/) (says SAR 130 to SAR 6,900, VAT included).
- I assume SAR because 0.0013 SAR per SMS would be far below the market. This needs confirming with sales.
- Store the per-SMS price in config (`app_config.sms_price_sar`), not in code.

---

## 2. What the owner's repos already do

### 2.1 `kolna-al-khafji-ios/supabase/functions/send-otp/index.ts` (246 lines): the best base

- **Storage** (`kolna-al-khafji-ios/supabase/migrations/20260750100000_phone_otp.sql`):
  - `phone_otp(id, phone, code /*HMAC*/, attempts, used, expires_at, created_at)` with an index on `(phone, used, created_at desc)`.
  - **RLS is enabled with no policies**, so only the service role can touch the table.
- **Hashing:** `HMAC-SHA256(OTP_HASH_SECRET, "otp:${phone}:${code}")`, and the plaintext is never stored or logged:
  ```ts
  const sig = await crypto.subtle.sign("HMAC", key, encoder.encode(`otp:${phone}:${code}`));
  ```
- **Code generation:** a CSPRNG via `crypto.getRandomValues`, giving a 6-digit code. Expiry is **10 minutes**. Older unused codes are invalidated on each send.
- **Rate limits:**
  - `COOLDOWN_SECONDS = 60`, `HOURLY_MAX = 5`, `DAILY_MAX = 10` per phone.
  - They are computed from a `select` of the last 24 h of `phone_otp` rows, then an `insert` (**not atomic**).
- **App Review bypass:** `DEV_PHONES` comes from the environment (default `+966500000000`) and uses the fixed code `000000`.
- **SMS call:**
  ```ts
  fetch("https://api.oursms.com/msgs/sms", { method: "POST",
    headers: { Authorization: `Bearer ${OURSMS_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({ src: OURSMS_SENDER, dests: [normalizedPhone], body: smsBody,
      msgClass: "transactional", priority: 1, validity: 10, maxParts: 1 }) })
  ```
  The sender comes from the `OURSMS_SENDER` secret. Errors 6307, 1001 and 1008 map to Arabic messages, and raw provider text stays in the server log.
- **`normalizePhone`:** converts Arabic-Indic digits, handles the `00` prefix and `05x` forms, and strips a trunk zero after the country code (+966, +965, +20).

### 2.2 `kolna-al-khafji-ios/supabase/functions/verify-otp/index.ts`

- `MAX_VERIFY_ATTEMPTS = 5`. A wrong code increments `attempts` and burns the row at 5.
- "Wrong code" and "expired" return the same message.
- The code is consumed only after the session is minted, so the `requires_registration` round trip can reuse it.
- **Sessions:** a synthetic email `${phone}@phone.kolnaalkhafji.app` plus an HMAC-derived password (`PASSWORD_SECRET`), then `signInWithPassword`, returning a GoTrue-shaped session.
- The iOS side is `kolna-al-khafji-ios/App/Sources/Backend/SupabaseAuthRepository.swift` (`sendOTP(phoneE164:)`) with `APIEndpoint.authentication.sendOTP` / `.verifyOTP` in `Packages/Networking/Sources/Networking/APIEndpoint.swift`.

### 2.3 `lamha_backup_ios/supabase/functions/send-otp/index.ts` (170 lines): do not reuse as-is

- The code is stored **in plaintext** (`insert({ phone, code, expires_at })`; `lamha_backup_ios/supabase/schema.sql` has no `attempts` column).
- It uses `Math.random()` instead of a CSPRNG.
- The rate limit is 10 per 5 minutes.
- `OURSMS_SENDER = "LamhaAds"` is hardcoded, with `priority: 0`, `validity: 3` and `transliteration: "AUTO"`, and there is no `msgClass`.
- **It logs the full payload, including the OTP** (`console.log("SMS payload:", JSON.stringify(smsPayload))`).
- It appends the raw OurSMS response to the client error.
- `lamha_backup_ios/supabase/functions/change-phone/index.ts` sends with `src: "Lamha"`. The comment in `send-otp` says that sender "was rejected", so phone change is likely broken in Lamha. This is out of scope for Munyati, but worth telling the owner.

### 2.4 Reusable push "campaign" pattern

`kolna-al-khafji-ios/supabase/migrations/20260732100000_notifications_rich.sql` has `notification_campaigns`. It writes one admin-visible row per send, evaluates the segment at send time and records a `recipient_count`. `admin_send_campaign(...)` is `security definer` with an `is_admin()` gate. The SMS campaign design in section 5 follows the same shape, adding scheduling, consent and delivery tracking.

---

## 3. Munyati OTP on OurSMS: implementation plan (Supabase Edge Functions, Deno)

### 3.1 What to change relative to Kolna

| # | Change | Why |
|---|---|---|
| 1 | Accept **Saudi mobiles only**: `^\+9665\d{8}$` (keep `DEV_PHONES` for App Review) | SMS pumping targets premium and foreign ranges. OurSMS warns about traffic concentrated in one country or prefix ([SMS pumping](https://oursms.com/en/sms-pumping/)) |
| 2 | Move cooldown, hourly, daily and **per-IP** limits into one **atomic** SQL function (advisory lock per phone) | Kolna's select-then-insert lets N parallel requests pass the same check |
| 3 | Make attempt counting atomic (`update … set attempts = attempts + 1 … returning`) | Kolna reads `attempts`, compares, then writes `attempts + 1`, so parallel guesses all see the same count and more than 5 guesses get through |
| 4 | Add a **global circuit breaker**: if OTP sends in the last hour exceed `app_config.otp_hourly_global_max`, refuse and alert admins | OurSMS recommends multiple limit levels and watching sends rise without matching verifications ([SMS pumping](https://oursms.com/en/sms-pumping/)) |
| 5 | Use IP as a secondary signal only. Read the first entry of `x-forwarded-for` and store a salted hash | Supabase populates `x-forwarded-for` ([discussion #7884](https://github.com/orgs/supabase/discussions/7884)), but users report it can be spoofed ([discussion #34647](https://github.com/orgs/supabase/discussions/34647)), so never make it the only limit |
| 6 | Expiry of 5 minutes and `validity: 5`. Keep 6 digits and the 5-attempt lockout | Shorter window, same UX. Kolna's 10 min also works; this is a judgement call |
| 7 | Keep the OTP wording in one constant that matches the OurSMS-approved text exactly | Accounts may be restricted to approved OTP text ([PR #10](https://github.com/hassanhmostafa/limlifestyle/pull/10)) |
| 8 | Pass `role` (`customer` / `provider`) and the name on the registration call of `verify-otp`. Write `profiles.role`. Change the synthetic email domain to `@phone.munyati.co` and use a Munyati-specific HMAC label (`munyati:${phone}`) | Requirement 1 (role chosen at auth) |
| 9 | Write every send to `sms_log` (no body for OTP) | Cost analytics, OTP send-to-verify conversion (pumping signal), requirement 9 |
| 10 | Optional: App Attest or DeviceCheck token on `send-otp` | Bot-risk check before calling the SMS API, as recommended in [SMS pumping](https://oursms.com/en/sms-pumping/) |

### 3.2 SQL (new migration, service-role only)

```sql
-- phone_otp: copy Kolna's table as-is (HMAC code, attempts, used, expires_at, RLS on with no policies).

create table public.otp_requests (
  id         bigint generated always as identity primary key,
  phone      text not null,
  ip_hash    text,
  created_at timestamptz not null default now()
);
create index otp_requests_phone_idx on public.otp_requests (phone, created_at desc);
create index otp_requests_ip_idx    on public.otp_requests (ip_hash, created_at desc);
alter table public.otp_requests enable row level security;   -- no policies

-- Atomic gate: returns 'ok' and records the request, or the reason it was refused.
create or replace function public.otp_reserve_send(p_phone text, p_ip_hash text)
returns text language plpgsql security definer set search_path = '' as $$
declare v_last timestamptz; v_hour int; v_day int; v_ip int; v_global int;
begin
  perform pg_advisory_xact_lock(hashtext('otp:' || p_phone));
  select max(created_at),
         count(*) filter (where created_at > now() - interval '1 hour'),
         count(*)
    into v_last, v_hour, v_day
    from public.otp_requests
   where phone = p_phone and created_at > now() - interval '24 hours';
  if v_last > now() - interval '60 seconds' then return 'cooldown'; end if;
  if v_hour >= 5  then return 'hourly'; end if;
  if v_day  >= 10 then return 'daily';  end if;
  if p_ip_hash is not null then
    select count(*) into v_ip from public.otp_requests
     where ip_hash = p_ip_hash and created_at > now() - interval '1 hour';
    if v_ip >= 20 then return 'ip'; end if;
  end if;
  select count(*) into v_global from public.otp_requests where created_at > now() - interval '1 hour';
  if v_global >= coalesce((select (value->>'otp_hourly_global_max')::int from public.app_config limit 1), 500)
    then return 'global'; end if;   -- adapt to however Munyati's app_config is shaped
  insert into public.otp_requests (phone, ip_hash) values (p_phone, p_ip_hash);
  return 'ok';
end $$;

-- Atomic verify: increments attempts first, then compares.
create or replace function public.otp_check(p_phone text, p_hash text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare r record;
begin
  update public.phone_otp o set attempts = o.attempts + 1
   where o.id = (select id from public.phone_otp
                  where phone = p_phone and not used and expires_at > now()
                  order by created_at desc limit 1 for update)
  returning o.id, o.code, o.attempts into r;
  if not found then return jsonb_build_object('status','invalid'); end if;
  if r.attempts > 5 then
    update public.phone_otp set used = true where id = r.id;
    return jsonb_build_object('status','locked');
  end if;
  if r.code <> p_hash then
    if r.attempts >= 5 then update public.phone_otp set used = true where id = r.id; end if;
    return jsonb_build_object('status','invalid');
  end if;
  return jsonb_build_object('status','ok','otp_id', r.id);  -- consume after the session is minted
end $$;

revoke all on function public.otp_reserve_send(text,text), public.otp_check(text,text)
  from public, anon, authenticated;
```

Prune `otp_requests` and `phone_otp` older than 7 days with a `pg_cron` job, following the same pattern as Kolna's `cleanup-anonymous-guests` cron.

### 3.3 Shared SMS client: `supabase/functions/_shared/sms.ts`

```ts
export type SmsClass = "transactional" | "promotional";
export interface SmsResult { ok: boolean; status: number; raw: string; errorCode?: string }

export async function sendSms(opts: {
  dests: string[]; body: string; msgClass: SmsClass;
  priority?: number; validity?: number; maxParts?: number;
}): Promise<SmsResult> {
  const key = Deno.env.get("OURSMS_API_KEY")!;
  const src = opts.msgClass === "promotional"
    ? Deno.env.get("OURSMS_SENDER_PROMO")!      // e.g. "Munyati-AD"
    : Deno.env.get("OURSMS_SENDER")!;           // e.g. "Munyati"
  if (opts.dests.length > 500) throw new Error("max 500 dests per request");
  const res = await fetch("https://api.oursms.com/msgs/sms", {
    method: "POST",
    headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
    body: JSON.stringify({ src, dests: opts.dests, body: opts.body, msgClass: opts.msgClass,
      priority: opts.priority ?? 0, validity: opts.validity, maxParts: opts.maxParts }),
  });
  const raw = await res.text();
  let errorCode: string | undefined;
  try { const j = JSON.parse(raw); errorCode = String(j?.errorCode ?? j?.code ?? "") || undefined; } catch { /**/ }
  return { ok: res.ok, status: res.status, raw, errorCode };
}
```

- The 500-recipient cap comes from the v1.0 doc. Confirm it applies to `/msgs/sms`.
- Once a staging send shows the response shape, extend `SmsResult` with the provider message id(s).

### 3.4 `send-otp` flow

1. Parse `{ phone }`, then run `normalizePhone` (Kolna's version, with the country list reduced to +966).
2. Reject anything that does not match `^\+9665\d{8}$`, unless it is in `DEV_PHONES`.
3. `ip_hash = sha256(IP_SALT + firstIp(x-forwarded-for))`.
4. Call `rpc('otp_reserve_send', { p_phone, p_ip_hash })`. Anything other than `ok` returns 429 with an Arabic message (`cooldown` includes the seconds remaining).
5. Generate the code with a CSPRNG. Set `used = true` on older rows and insert the HMAC with `expires_at = now() + 5 min`.
6. Call `sendSms({ dests:[phone], body: OTP_TEXT(code), msgClass:"transactional", priority:1, validity:5, maxParts:1 })`.
7. Insert into `sms_log` with `kind='otp'`, no body, the status and the error code. On failure, map 6307/1001/1008 like Kolna and return a generic Arabic error; the detail stays in the logs. Emit an `error_logs` row (requirement 9).

### 3.5 `verify-otp` flow

1. Call `rpc('otp_check', { p_phone, p_hash: hmac(...) })`.
2. If the status is `ok`:
   - Find the profile by phone. If none exists and no `role`/`name` was sent, return `{ requires_registration: true }` (Kolna pattern).
   - Otherwise create the auth user with `user_metadata.role`.
   - `signInWithPassword` with the derived password.
   - Set `phone_otp.used = true` for that `otp_id`.
   - Return the session.
3. Log `auth_otp_verified` / `auth_otp_failed` analytics events. OTP send-to-verify conversion goes on the dashboard as an SMS-pumping alarm.

### 3.6 Secrets

`OURSMS_API_KEY`, `OURSMS_SENDER`, `OURSMS_SENDER_PROMO`, `OTP_HASH_SECRET`, `PASSWORD_SECRET`, `IP_SALT`, `DEV_PHONES`. Deploy `send-otp` and `verify-otp` with `--no-verify-jwt`, as Kolna does.

---

## 4. Saudi sender-name and marketing rules (to confirm with OurSMS and CST)

**Sender name registration (OurSMS help centre, [request sender ID](https://oursms.com/en/documentation/others-en/request-sms-sender-id/)):**
- Companies must provide a copy of their CR; charities provide their license.
- The sender name must have a "clear and direct relationship" with the CR or business activity. Otherwise supporting documents are needed: a trademark certificate, municipal license, SFDA certificate, or proof of owning a **Saudi** domain, among others.
- English sender names are max 11 characters, and **promotional sender names are max 8**.
- The process is: authorization letter, then contract, then a request form with the documents.
- Turnaround and fees were not found on OurSMS. Third parties cite 14 to 20 business days and conflicting fees ([search summary of Clickatell](https://www.clickatell.com/sms-country-regulations/saudi-arabia/), [Telnyx](https://support.telnyx.com/en/articles/6680009-saudi-arabia-sms-guidelines), [D7](https://d7networks.com/blog/send-sms-in-saudi-arabia-regulations-best-practices/)).
- **Implication:** the CR holder must match "Munyati / منيتي". `munyati.co` does not count as a Saudi domain. Start sender registration **now**, because OTP cannot launch without an approved sender (error 6307).

**Promotional vs transactional:**
- Promotional sender IDs carry a `-AD` suffix, and it counts toward the 11-character limit ([Bird](https://bird.com/sms-api/features/destinations/saudi-arabia), [ClickSend](https://help.clicksend.com/en/articles/43566-saudi-arabia-966), [Clickatell](https://www.clickatell.com/sms-country-regulations/saudi-arabia/)).
- Transactional traffic uses a separate registered ID without the suffix and may be sent 24/7. If you send both kinds, you need two IDs (same sources).
- The OurSMS "max 8 for promotional" may mean 8 characters plus `-AD`. "Munyati" is 7 characters, so `Munyati-AD` (10 characters) fits either reading.
- Mobily reportedly blocks or suspended `-AD` traffic at times ([Clickatell](https://www.clickatell.com/sms-country-regulations/saudi-arabia/), [Telnyx](https://support.telnyx.com/en/articles/6680009-saudi-arabia-sms-guidelines)). **Expect lower delivery rates on promotional sends.**

**Sending hours for promotional SMS** (sources disagree; Asia/Riyadh time):

| Window | Source |
|---|---|
| 06:00–19:00 | [Telnyx](https://support.telnyx.com/en/articles/6680009-saudi-arabia-sms-guidelines) (search summary) |
| 08:00–21:00 | [Clickatell](https://www.clickatell.com/sms-country-regulations/saudi-arabia/), [160.com.au](https://www.160.com.au/saudi-arabia-sms-laws-and-regulations) |
| 08:00–22:00 (and "not delivered 21:00–07:00") | [SMSCountry](https://www.smscountry.com/blog/sms-regulations-saudi-arabia/) |

The window that satisfies every source is **08:00–19:00**. Make the window configurable in `app_config` and default to **09:00–19:00**. Transactional messages (OTP, booking updates) have no time limit.

**Consent and opt-out:**
- Prior opt-in is required for promotional SMS, and purchase history is not consent ([smsboosting](https://smsboosting.com/sms-marketing-ksa/)).
- STC promotional traffic must end with an opt-out text ("SMS STOP to opt out") ([Clickatell](https://www.clickatell.com/sms-country-regulations/saudi-arabia/)).
- Numbers on the DND list are filtered out by the network ([SMSCountry](https://www.smscountry.com/blog/sms-regulations-saudi-arabia/)).
- URLs must be whitelisted and shorteners are not allowed ([Bird](https://bird.com/sms-api/features/destinations/saudi-arabia), [Clickatell](https://www.clickatell.com/sms-country-regulations/saudi-arabia/)).

**PDPL:**
- Direct marketing needs prior consent, a way to withdraw it, and a stop "without undue delay" after withdrawal. The draft amendments require consent to be **documented** and easy to withdraw ([Clyde & Co, 2025](https://www.clydeco.com/en/insights/2025/05/saudi-arabia-new-pdp-law-consultation)).
- A separate "Regulations for Curbing SPAM Messages & Calls" also applies ([Al Tamimi](https://turtl.tamimi.com/story/law-update-issue-367-saudi-arabia-and-competition/page/11)). I could not read its text.
- I found **no primary CST document**. Every rule above is secondary. Ask OurSMS for their compliance sheet; Taqnyat publishes one ([compliance-en.pdf](https://taqnyat.sa/assets/download/compliance-en.pdf)), but I could not open it.

---

## 5. Dashboard feature design: SMS marketing campaigns

This builds on the Kolna `notification_campaigns` pattern (one campaign row, segment evaluated at send time, `is_admin()` RPCs) and the Lamha Next.js dashboard (`lamha_dahsboard`, Next.js 14 + `@supabase/ssr`).

### 5.1 Data model

```sql
-- Consent: current state on the profile plus an append-only history (PDPL: documented consent).
alter table public.profiles
  add column sms_marketing_opt_in boolean not null default false,  -- off by default
  add column last_active_at timestamptz;                          -- updated by the analytics/session ping

create table public.consent_events (
  id bigint generated always as identity primary key,
  user_id uuid references public.profiles(id) on delete set null,
  phone text not null,
  channel text not null check (channel in ('sms','push','email')),
  action text not null check (action in ('opt_in','opt_out')),
  source text not null,          -- 'signup_checkbox' | 'settings_toggle' | 'sms_stop' | 'unsubscribe_link' | 'admin'
  consent_text_version text,     -- which wording the user saw
  app_version text,
  created_at timestamptz not null default now()
);

-- Phone-level suppression survives account deletion and re-signup.
create table public.sms_suppressions (
  phone text primary key,
  reason text not null check (reason in ('opt_out','stop_reply','admin','invalid_number','dnd','complaint')),
  created_at timestamptz not null default now()
);

create table public.sms_templates (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  body text not null,                       -- supports {{first_name}}, {{city}}, {{link}}
  msg_class text not null default 'promotional' check (msg_class in ('promotional','transactional')),
  link_url text,                            -- must be a whitelisted munyati.co URL; no shorteners
  status text not null default 'draft' check (status in ('draft','approved','archived')),
  created_by uuid, approved_by uuid, created_at timestamptz default now(), updated_at timestamptz default now()
);

create table public.sms_campaigns (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  template_id uuid references public.sms_templates(id),
  body_snapshot text not null,              -- frozen at schedule time, opt-out footer included
  audience jsonb not null,                  -- see 5.2
  scheduled_at timestamptz,                 -- null = send now (still subject to the quiet-hours window)
  status text not null default 'draft'
    check (status in ('draft','pending_approval','scheduled','sending','paused','sent','cancelled','failed')),
  recipient_count int, segments_per_msg int, est_cost_sar numeric(10,2), actual_cost_sar numeric(10,2),
  created_by uuid, approved_by uuid, created_at timestamptz default now(), sent_at timestamptz
);

create table public.sms_campaign_recipients (
  campaign_id uuid references public.sms_campaigns(id) on delete cascade,
  user_id uuid, phone text not null,
  status text not null default 'queued'
    check (status in ('queued','sent','delivered','failed','undelivered','skipped_suppressed','skipped_cap')),
  provider_msg_id text, error_code text,
  sent_at timestamptz, delivered_at timestamptz,
  primary key (campaign_id, phone)
);
create index on public.sms_campaign_recipients (provider_msg_id);

-- One log for every SMS (OTP, transactional, campaign): cost and error analytics.
create table public.sms_log (
  id bigint generated always as identity primary key,
  kind text not null check (kind in ('otp','transactional','campaign','test')),
  campaign_id uuid, phone_hash text, segments int, http_status int, error_code text,
  created_at timestamptz default now()
);
```

RLS: enable it on all of these tables with admin-only policies (`is_admin()`). Users can read and update only their own `sms_marketing_opt_in`, through an RPC that also writes `consent_events`.

### 5.2 Audience builder

`audience` JSON:

```json
{ "roles": ["customer"],              // customer | provider | both
  "city_ids": ["all"],                // or a list of city UUIDs (multi-select + "All", matches requirement 16)
  "last_active": { "within_days": 30 },     // or { "inactive_for_days": 60 } for win-back
  "provider_plan": ["normal","plus"],       // optional, providers only (e.g. trial ending)
  "provider_trial_state": "ending_7d",      // optional: trial ends within 7 days (requirement 24 conversion)
  "has_booking_status": null,               // optional, e.g. brides with no booking yet
  "opted_in_only": true }                   // forced true when msg_class = 'promotional'
```

The RPC `admin_sms_audience_preview(p_audience jsonb, p_body text)` returns:
- `recipient_count`, after excluding suppressed numbers, admins, users without a phone, and anyone over the frequency cap (e.g. at most 4 promotional SMS per 30 days, set in `app_config`);
- `segments_per_msg` and `est_cost_sar` (see 5.4);
- 5 sample masked phones;
- a breakdown by city and role.

### 5.3 Templates and content rules (enforced in the editor and again in SQL)

- A live character and segment counter: GSM-7 is 160 / 153 per part, and UCS-2 (any Arabic character) is 70 / 67 per part ([GSM 03.40](https://en.wikipedia.org/wiki/GSM_03.40) for the concatenation header; these are the standard GSM figures).
- Arabic template bodies should aim for at most 2 segments (134 characters).
- A mandatory footer is appended automatically to promotional sends, e.g. `لإلغاء الاشتراك أرسل STOP` and/or a whitelisted `munyati.co/u/{token}` link (handled as a universal link plus a web fallback page). Confirm the exact opt-out wording OurSMS and the operators require.
- Links must be `munyati.co` URLs (whitelisted with OurSMS), with no shorteners. Use a path such as `munyati.co/c/{campaign_slug}` so the universal link opens the app and logs a `campaign_open` analytics event with `campaign_id`.
- Placeholders are rendered per recipient. Personalised bodies cannot be batched as one 500-destination request, so prefer non-personalised bodies for large sends.
- Two-person rule: a marketing admin creates the template, and a super-admin approves it (`status = 'approved'`). This needs a role richer than Kolna's binary `user`/`admin`, as noted in `docs/research/kolna-backend.md`.

### 5.4 Cost estimate

`est_cost_sar = recipient_count × segments_per_msg × app_config.sms_price_sar`

- Example: 5,000 opted-in brides × 1 Arabic segment × SAR 0.10 (5k-package rate, [blog](https://oursms.com/en/whatsapp-vs-sms-cost-in-saudi-arabia-2026-oursms/)) is about **SAR 500 per campaign**. A 2-segment message doubles that.
- Before sending, check the OurSMS balance. v1.0 had `api-a/billing/credits` ([PDF](https://oursms.net/files4Download/Oursmsupdatedapi.pdf)); ask OurSMS for the `/msgs`-era equivalent. Block the send if the estimate exceeds the balance (error 1008 in the owner's mapping).

### 5.5 Scheduling and dispatch

- A `pg_cron` job runs every minute and calls the `sms-campaign-dispatch` Edge Function through `pg_net`. The function:
  1. Picks campaigns with `status='scheduled' and scheduled_at <= now()`. It exits if the current Asia/Riyadh time is outside the promotional window; the campaign stays scheduled and rolls to the next window.
  2. On the first run, materialises `sms_campaign_recipients` from the audience. It re-checks suppressions and consent **at send time**, because someone may have opted out after scheduling.
  3. Sends batches of at most 500 numbers per request with `msgClass: "promotional"`, `src: OURSMS_SENDER_PROMO` and a small concurrency (rate limits are unknown, so start with one request at a time and back off on 429 or 5xx).
  4. Records `provider_msg_id` and the status per recipient, and writes `sms_log`.
  5. Is idempotent: it only sends rows still `queued`, so a crash mid-run resumes safely. Admins can **Pause** or **Cancel** between batches.
- A **test send** goes only to admin phones, using the same path with `kind='test'`.

### 5.6 Delivery stats

- **Preferred:** an `sms-dlr-webhook` Edge Function, if OurSMS confirms webhooks for `/msgs/sms` ([developers](https://oursms.com/en/developers-2/)). It verifies the signature, looks up `provider_msg_id` and updates `status` and `delivered_at` idempotently, ignoring older events ([guidance](https://oursms.com/en/whatsapp-sms-fallback-how-to-keep-critical-messages-deliverable/)).
- **Fallback:** poll a status endpoint for up to 48 h after the send. The endpoint is unknown; the old `oursms.app` API had `GetStatus/{id}`, which is not usable.
- Dashboard per campaign:
  - queued, sent, delivered, failed and undelivered counts;
  - delivery rate by operator, if DLRs carry it;
  - opt-outs attributed to the campaign (`consent_events` within 72 h with `source in ('sms_stop','unsubscribe_link')`);
  - link opens and attributed bookings (`campaign_open` then `booking_created` with the same `campaign_id`);
  - actual cost against the estimate.
- Global SMS page: spend per day by kind (OTP, transactional, campaign), OTP send-to-verify conversion, and the top error codes.

### 5.7 Opt-in and opt-out handling

- **Opt-in:**
  - An **unchecked** checkbox on the registration step after OTP, for both roles. Brides could also see it on the budget onboarding screen.
  - A toggle in Profile & Settings: "عروض وتنبيهات تسويقية عبر SMS".
  - Each change writes `consent_events` with `consent_text_version`.
  - Transactional SMS (OTP, booking approved, payment proof rejected) do not need marketing consent. Prefer push for those to save cost.
- **Opt-out channels:**
  1. The in-app toggle.
  2. The `munyati.co/u/{signed token}` page, which works without logging in.
  3. A "STOP" reply. **It is unknown whether OurSMS forwards inbound replies or keeps its own STOP list.** Ask, and if a suppression-list export or webhook exists, sync it daily into `sms_suppressions`.
  4. Admin action from a support ticket (requirement 28).
- Every opt-out takes effect immediately for queued sends, because dispatch re-checks at send time.
- **Account deletion:** keep the phone in `sms_suppressions` (the minimum data needed to honour the opt-out) and delete everything else.

### 5.8 Dashboard pages (Next.js, following the `lamha_dahsboard` conventions)

| Page | What it does |
|---|---|
| `/sms/campaigns` | List, create, preview audience, test send, schedule, pause or cancel, view stats |
| `/sms/templates` | CRUD, segment counter, approve |
| `/sms/suppressions` | Search, add or remove (removal requires recorded re-consent), CSV export |
| `/sms/health` | Balance, spend, OTP conversion, error codes, circuit-breaker state, sender names in use |
| `/settings/sms` | Price per SMS, promotional window, frequency cap, global OTP cap, footer text |

---

## 6. Open questions for OurSMS (send before building)

1. Full reference for `https://api.oursms.com/msgs/*`: the success and error schemas, the message-id field, whether `dests` is capped at 500, the meaning of `validity`, `maxParts`, `transliteration` and `msgClass`.
2. The OTP API (endpoint and parameters). Does it handle templates and approved text for us?
3. The webhook (DLR) payload, signature scheme and retry policy. Is there a status-polling endpoint?
4. The balance or credits endpoint for the current API.
5. Rate limits (requests per second and concurrency) per API key.
6. Inbound STOP handling and any suppression-list API. The exact opt-out wording required per operator.
7. Sender registration for "Munyati" / "منيتي" and "Munyati-AD": documents, turnaround and fees, given that the domain is `.co`, not `.sa`.
8. Current per-SMS pricing (SAR or halala?), whether VAT is included, and whether promotional and transactional are priced differently.
9. The current permitted promotional hours, and Mobily's `-AD` status.

## 7. Reuse checklist

| Item | Status for Munyati |
|---|---|
| `kolna-al-khafji-ios/supabase/functions/send-otp` / `verify-otp` | **Adapt**: Saudi-only, atomic limits, IP hash, role on registration, Munyati email domain and HMAC label, `sms_log` |
| `kolna-al-khafji-ios/supabase/migrations/20260750100000_phone_otp.sql` | **Reuse as-is**, plus the new `otp_requests` table and RPCs |
| Kolna iOS `SupabaseAuthRepository.sendOTP` + `APIEndpoint.authentication.*` | **Reuse** (rename and add the role parameter) |
| Lamha `send-otp` / `change-phone` | **Do not reuse** (plaintext codes, logs the OTP, hardcoded sender) |
| Kolna `notification_campaigns` / `admin_send_campaign` | **Pattern** for push campaigns. Extend it for SMS (scheduling, consent, DLR) |
| SMS marketing tables, dispatch function, DLR webhook, dashboard pages | **Missing**: build them (section 5) |
| Approved sender names (OTP + `-AD`) | **Missing**: start registration with OurSMS now |
