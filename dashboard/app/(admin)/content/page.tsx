import Link from "next/link";
import { supabaseServer } from "@/lib/supabase/server";
import { Chips, Flash } from "@/components/ui";
import { param } from "@/lib/format";
import { i18n } from "@/lib/i18n";
import { savePage, saveString } from "./actions";

type Page = { slug: string; lang: string; title: string; body_markdown: string; is_published: boolean; updated_at: string };

export default async function Content({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const sp = await searchParams;
  const tab = param(sp.tab, "pages");
  const { t, dateTime: fmtDateTime } = await i18n();
  const tabs: [string, string][] = [["pages", t("الصفحات", "Pages")], ["strings", t("النصوص", "Strings")]];
  const supabase = await supabaseServer();

  if (tab === "strings") {
    const { data } = await supabase.from("app_strings").select("*").order("key");
    return (
      <>
        <div className="topbar"><h1>{t("نصوص التطبيق", "App strings")}</h1></div>
        <Chips base="/content" name="tab" current={tab} options={tabs} />
        <Flash sp={sp} />
        <p className="muted">{t("تستبدل نصوص التطبيق (شاشات الحساب والقوائم) دون تحديث. اكتبي المفتاح كما في التطبيق، واتركي القيمة فارغة لحذف الاستبدال.", "Overrides app texts (account screens and menus) without an update. Enter the key as used in the app; leave the value empty to remove the override.")}</p>
        <div className="table-wrap">
          <table>
            <thead><tr><th>{t("المفتاح", "Key")}</th><th>{t("اللغة", "Language")}</th><th>{t("النص", "Text")}</th><th></th></tr></thead>
            <tbody>
              {(data ?? []).map((s) => (
                <tr key={`${s.key}-${s.lang}`}>
                  <td colSpan={4}>
                    <form className="inline" action={saveString}>
                      <input name="key" defaultValue={s.key} readOnly dir="ltr" className="mono" style={{ width: 220 }} />
                      <input name="lang" defaultValue={s.lang} readOnly style={{ width: 50 }} />
                      <input name="value" defaultValue={s.value} style={{ flex: 1, minWidth: 200 }} dir={s.lang === "en" ? "ltr" : "rtl"} />
                      <button className="secondary">{t("حفظ", "Save")}</button>
                    </form>
                  </td>
                </tr>
              ))}
              <tr><td colSpan={4}>
                <form className="inline" action={saveString}>
                  <input name="key" placeholder="profile.support" required dir="ltr" className="mono" style={{ width: 220 }} />
                  <select name="lang"><option value="ar">ar</option><option value="en">en</option></select>
                  <input name="value" placeholder={t("النص الجديد", "New text")} required style={{ flex: 1, minWidth: 200 }} />
                  <button>{t("إضافة", "Add")}</button>
                </form>
              </td></tr>
            </tbody>
          </table>
        </div>
      </>
    );
  }

  const { data } = await supabase.from("cms_pages").select("*").order("slug");
  const pages = (data ?? []) as Page[];
  const slug = param(sp.page);
  const lang = param(sp.lang, "ar");
  const editing = pages.find((p) => p.slug === slug && p.lang === lang);

  return (
    <>
      <div className="topbar"><h1>{t("صفحات المحتوى", "Content pages")}</h1></div>
      <Chips base="/content" name="tab" current={tab} options={tabs} />
      <Flash sp={sp} />
      <div className="grid two">
        <div className="card">
          <p className="muted small">{t("الشروط والخصوصية وعن منيتي والأسئلة الشائعة. تظهر في التطبيق والموقع (Markdown).", "Terms, privacy, about and FAQ. Shown in the app and on the website (Markdown).")}</p>
          {pages.map((p) => (
            <div key={`${p.slug}-${p.lang}`} style={{ display: "flex", justifyContent: "space-between", marginBottom: 6 }}>
              <Link href={`/content?page=${p.slug}&lang=${p.lang}`}>{p.title} <span className="muted mono">{p.slug}/{p.lang}</span></Link>
              <span className="small muted">{p.is_published ? fmtDateTime(p.updated_at) : t("مسودة", "Draft")}</span>
            </div>
          ))}
          <Link className="button secondary" href="/content?page=new">{t("صفحة جديدة", "New page")}</Link>
        </div>
        {(editing || slug === "new") && (
          <form className="card stack" action={savePage} key={`${slug}-${lang}`}>
            <div className="grid two">
              <label>{t("المعرّف", "Slug")}<input name="slug" defaultValue={editing?.slug ?? ""} required readOnly={!!editing} dir="ltr" placeholder="faq" /></label>
              <label>{t("اللغة", "Language")}
                <select name="lang" defaultValue={editing?.lang ?? "ar"} disabled={!!editing}><option value="ar">العربية</option><option value="en">English</option></select>
                {editing && <input type="hidden" name="lang" value={editing.lang} />}
              </label>
            </div>
            <label>{t("العنوان", "Title")}<input name="title" defaultValue={editing?.title ?? ""} required /></label>
            <label>{t("المحتوى (Markdown)", "Content (Markdown)")}<textarea name="body" defaultValue={editing?.body_markdown ?? ""} style={{ minHeight: 320 }} dir={lang === "en" ? "ltr" : "rtl"} required /></label>
            <label className="check"><input type="checkbox" name="is_published" defaultChecked={editing?.is_published ?? true} /> {t("منشورة", "Published")}</label>
            <button>{t("حفظ الصفحة", "Save page")}</button>
          </form>
        )}
      </div>
    </>
  );
}
