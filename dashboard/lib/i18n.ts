import { cache } from "react";
import { cookies } from "next/headers";

// Dashboard language: Arabic (default, RTL) or English (LTR), kept in the `lang` cookie and
// switched by `setLang` (app/lang.ts). Server components call `await i18n()` once per request.

export type Lang = "ar" | "en";
/** An Arabic / English pair, used by the label maps in lib/labels.ts. */
export type Pair = readonly [ar: string, en: string];

export const LANG_COOKIE = "lang";

export const getLang = cache(async (): Promise<Lang> =>
  (await cookies()).get(LANG_COOKIE)?.value === "en" ? "en" : "ar");

export function makeI18n(lang: Lang) {
  const locale = lang === "ar" ? "ar-SA-u-nu-latn" : "en-GB";
  const t = (ar: string, en: string) => (lang === "ar" ? ar : en);
  return {
    lang,
    dir: lang === "ar" ? ("rtl" as const) : ("ltr" as const),
    t,
    /** The label for `key` in an [ar, en, …] map, or the raw key when it's unknown. */
    label: (map: Record<string, readonly string[]>, key?: string | null) => {
      const entry = key ? map[key] : undefined;
      return entry ? entry[lang === "ar" ? 0 : 1] : key || "—";
    },
    /** Joins a list with the language's comma. */
    list: (items: string[]) => items.join(t("، ", ", ")),
    /** Arrow for "from → to", pointing in reading direction. */
    arrow: t("←", "→"),
    date: (v?: string | null) =>
      v ? new Date(v).toLocaleDateString(locale, { year: "numeric", month: "short", day: "numeric", timeZone: "Asia/Riyadh" }) : "—",
    dateTime: (v?: string | null) =>
      v ? new Date(v).toLocaleString(locale, { dateStyle: "medium", timeStyle: "short", timeZone: "Asia/Riyadh" }) : "—",
    num: (v?: number | string | null) => (v == null ? "—" : Number(v).toLocaleString(locale)),
    sar: (v?: number | string | null) =>
      v == null ? "—" : `${Number(v).toLocaleString(locale, { maximumFractionDigits: 2 })} ${t("ر.س", "SAR")}`,
  };
}

export type I18n = ReturnType<typeof makeI18n>;

/** Strings and formatters in the signed-in admin's language (memoised per request). */
export const i18n = cache(async () => makeI18n(await getLang()));
