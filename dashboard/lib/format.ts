// Dates, numbers and money are formatted in the admin's language: see `i18n()` in lib/i18n.ts.

/** Reads a string search param (Next passes string | string[] | undefined). */
export const param = (v: string | string[] | undefined, fallback = "") => (Array.isArray(v) ? v[0] : v) ?? fallback;

export const PAGE_SIZE = 30;
export const pageRange = (page: number) => [(page - 1) * PAGE_SIZE, page * PAGE_SIZE - 1] as const;
