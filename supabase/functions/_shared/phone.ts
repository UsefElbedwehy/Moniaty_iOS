// Munyati serves Saudi Arabia only: every phone is normalised to +9665XXXXXXXX.

/** Converts Arabic-Indic digits and common local formats to E.164, or returns null if the
 *  number is not a Saudi mobile. Accepts "05X…", "5X…", "9665X…", "009665X…" and "+9665X…". */
export function normalizeSaudiMobile(raw: string): string | null {
  const ascii = raw
    .replace(/[٠-٩]/g, (d) => String(d.charCodeAt(0) - 0x0660))
    .replace(/[۰-۹]/g, (d) => String(d.charCodeAt(0) - 0x06F0))
    .replace(/[\s\-()]/g, "");
  let digits = ascii.replace(/^\+/, "").replace(/^00/, "");
  if (digits.startsWith("05") && digits.length === 10) digits = "966" + digits.slice(1);
  if (digits.startsWith("5") && digits.length === 9) digits = "966" + digits;
  return /^9665\d{8}$/.test(digits) ? `+${digits}` : null;
}
