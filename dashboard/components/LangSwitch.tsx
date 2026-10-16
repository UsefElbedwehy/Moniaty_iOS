import { setLang } from "@/app/lang";
import type { Lang } from "@/lib/i18n";

/** «English» in Arabic mode, «عربي» in English mode. */
export function LangSwitch({ lang }: { lang: Lang }) {
  const other = lang === "ar" ? "en" : "ar";
  return (
    <form action={setLang}>
      <input type="hidden" name="lang" value={other} />
      <button className="secondary" type="submit" lang={other}>{other === "en" ? "English" : "عربي"}</button>
    </form>
  );
}
