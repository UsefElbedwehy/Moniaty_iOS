import Link from "next/link";
import { supabaseServer } from "@/lib/supabase/server";
import { Chips, Flash } from "@/components/ui";
import { fmtDateTime, param } from "@/lib/format";
import { savePage, saveString } from "./actions";

type Page = { slug: string; lang: string; title: string; body_markdown: string; is_published: boolean; updated_at: string };

export default async function Content({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const sp = await searchParams;
  const tab = param(sp.tab, "pages");
  const supabase = await supabaseServer();

  if (tab === "strings") {
    const { data } = await supabase.from("app_strings").select("*").order("key");
    return (
      <>
        <div className="topbar"><h1>نصوص التطبيق</h1></div>
        <Chips base="/content" name="tab" current={tab} options={[["pages", "الصفحات"], ["strings", "النصوص"]]} />
        <Flash sp={sp} />
        <p className="muted">تستبدل نصوص التطبيق (شاشات الحساب والقوائم) دون تحديث. اكتبي المفتاح كما في التطبيق، واتركي القيمة فارغة لحذف الاستبدال.</p>
        <div className="table-wrap">
          <table>
            <thead><tr><th>المفتاح</th><th>اللغة</th><th>النص</th><th></th></tr></thead>
            <tbody>
              {(data ?? []).map((s) => (
                <tr key={`${s.key}-${s.lang}`}>
                  <td colSpan={4}>
                    <form className="inline" action={saveString}>
                      <input name="key" defaultValue={s.key} readOnly dir="ltr" className="mono" style={{ width: 220 }} />
                      <input name="lang" defaultValue={s.lang} readOnly style={{ width: 50 }} />
                      <input name="value" defaultValue={s.value} style={{ flex: 1, minWidth: 200 }} dir={s.lang === "en" ? "ltr" : "rtl"} />
                      <button className="secondary">حفظ</button>
                    </form>
                  </td>
                </tr>
              ))}
              <tr><td colSpan={4}>
                <form className="inline" action={saveString}>
                  <input name="key" placeholder="profile.support" required dir="ltr" className="mono" style={{ width: 220 }} />
                  <select name="lang"><option value="ar">ar</option><option value="en">en</option></select>
                  <input name="value" placeholder="النص الجديد" required style={{ flex: 1, minWidth: 200 }} />
                  <button>إضافة</button>
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
      <div className="topbar"><h1>صفحات المحتوى</h1></div>
      <Chips base="/content" name="tab" current={tab} options={[["pages", "الصفحات"], ["strings", "النصوص"]]} />
      <Flash sp={sp} />
      <div className="grid two">
        <div className="card">
          <p className="muted small">الشروط والخصوصية وعن منيتي والأسئلة الشائعة. تظهر في التطبيق والموقع (Markdown).</p>
          {pages.map((p) => (
            <div key={`${p.slug}-${p.lang}`} style={{ display: "flex", justifyContent: "space-between", marginBottom: 6 }}>
              <Link href={`/content?page=${p.slug}&lang=${p.lang}`}>{p.title} <span className="muted mono">{p.slug}/{p.lang}</span></Link>
              <span className="small muted">{p.is_published ? fmtDateTime(p.updated_at) : "مسودة"}</span>
            </div>
          ))}
          <Link className="button secondary" href="/content?page=new">صفحة جديدة</Link>
        </div>
        {(editing || slug === "new") && (
          <form className="card stack" action={savePage} key={`${slug}-${lang}`}>
            <div className="grid two">
              <label>المعرّف<input name="slug" defaultValue={editing?.slug ?? ""} required readOnly={!!editing} dir="ltr" placeholder="faq" /></label>
              <label>اللغة
                <select name="lang" defaultValue={editing?.lang ?? "ar"} disabled={!!editing}><option value="ar">العربية</option><option value="en">English</option></select>
                {editing && <input type="hidden" name="lang" value={editing.lang} />}
              </label>
            </div>
            <label>العنوان<input name="title" defaultValue={editing?.title ?? ""} required /></label>
            <label>المحتوى (Markdown)<textarea name="body" defaultValue={editing?.body_markdown ?? ""} style={{ minHeight: 320 }} dir={lang === "en" ? "ltr" : "rtl"} required /></label>
            <label className="check"><input type="checkbox" name="is_published" defaultChecked={editing?.is_published ?? true} /> منشورة</label>
            <button>حفظ الصفحة</button>
          </form>
        )}
      </div>
    </>
  );
}
