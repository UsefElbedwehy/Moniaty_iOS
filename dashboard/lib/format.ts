// Dates, numbers and money are formatted in the admin's language: see `i18n()` in lib/i18n.ts.

/** Reads a string search param (Next passes string | string[] | undefined). */
export const param = (v: string | string[] | undefined, fallback = "") => (Array.isArray(v) ? v[0] : v) ?? fallback;

export const PAGE_SIZE = 30;
export const pageRange = (page: number) => [(page - 1) * PAGE_SIZE, page * PAGE_SIZE - 1] as const;

/**
 * A photo's small copy for thumbnails. Photos uploaded since thumbnails exist end in `.full.jpg`
 * and have a `.thumb.jpg` (600 px) beside them; older ones are returned as they are. Same rule as
 * the apps' `MediaThumbnail`.
 */
export const thumbUrl = (url: string) => (url.endsWith(".full.jpg") ? url.slice(0, -".full.jpg".length) + ".thumb.jpg" : url);
