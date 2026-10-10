const locale = "ar-SA-u-nu-latn";

export const fmtDate = (v?: string | null) =>
  v ? new Date(v).toLocaleDateString(locale, { year: "numeric", month: "short", day: "numeric", timeZone: "Asia/Riyadh" }) : "—";

export const fmtDateTime = (v?: string | null) =>
  v ? new Date(v).toLocaleString(locale, { dateStyle: "medium", timeStyle: "short", timeZone: "Asia/Riyadh" }) : "—";

export const fmtNum = (v?: number | string | null) => (v == null ? "—" : Number(v).toLocaleString(locale));

export const fmtSAR = (v?: number | string | null) =>
  v == null ? "—" : `${Number(v).toLocaleString(locale, { maximumFractionDigits: 2 })} ر.س`;

/** Reads a string search param (Next passes string | string[] | undefined). */
export const param = (v: string | string[] | undefined, fallback = "") => (Array.isArray(v) ? v[0] : v) ?? fallback;

export const PAGE_SIZE = 30;
export const pageRange = (page: number) => [(page - 1) * PAGE_SIZE, page * PAGE_SIZE - 1] as const;
