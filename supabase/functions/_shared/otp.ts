// OTP helpers. Codes are never stored in plain text: only an HMAC of phone + code.

async function hmacHex(secret: string, message: string): Promise<string> {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw", encoder.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, encoder.encode(message));
  return Array.from(new Uint8Array(sig)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

export function hashOTP(phone: string, code: string, secret: string): Promise<string> {
  return hmacHex(secret, `otp:${phone}:${code}`);
}

/** The password of the synthetic email account behind a phone number. Deterministic from a
 *  server secret, so it never needs storing and the user never sees it. */
export function derivePassword(phone: string, secret: string): Promise<string> {
  return hmacHex(secret, `munyati:${phone}`);
}

/** A 6-digit code from a CSPRNG. */
export function generateOTP(): string {
  const buf = new Uint32Array(1);
  crypto.getRandomValues(buf);
  return String(100000 + (buf[0] % 900000));
}

/** Test numbers that accept a fixed code. Only active when both env vars are set, so a
 *  missing variable can never open a back door. */
export function devBypass(phone: string, code: string): boolean {
  const phones = (Deno.env.get("DEV_PHONES") ?? "").split(",").map((s) => s.trim()).filter(Boolean);
  const devCode = Deno.env.get("DEV_OTP_CODE") ?? "";
  return devCode.length === 6 && phones.includes(phone) && code === devCode;
}
