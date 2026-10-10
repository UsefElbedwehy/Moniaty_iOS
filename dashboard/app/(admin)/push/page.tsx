import { supabaseServer } from "@/lib/supabase/server";
import { Flash } from "@/components/ui";
import { ConfirmButton } from "@/components/ConfirmButton";
import { fmtDateTime } from "@/lib/format";
import { sendCampaign } from "./actions";

export default async function Push({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const sp = await searchParams;
  const supabase = await supabaseServer();
  const [{ data: cities }, { data: history }] = await Promise.all([
    supabase.from("cities").select("id, name_ar").eq("is_active", true).order("sort_order"),
    supabase.from("admin_audit_log").select("after, created_at").eq("entity_type", "campaigns").order("created_at", { ascending: false }).limit(20),
  ]);
  return (
    <>
      <div className="topbar"><h1>الإشعارات</h1></div>
      <Flash sp={sp} />
      <div className="grid two">
        <form className="card stack" action={sendCampaign}>
          <label>الجمهور
            <select name="audience"><option value="brides">العرائس</option><option value="providers">مقدّمات الخدمة</option><option value="all">الجميع</option></select>
          </label>
          <div>
            <div className="small muted">المدن (بدون اختيار = كل المدن)</div>
            <div style={{ display: "flex", gap: 12, flexWrap: "wrap" }}>
              {(cities ?? []).map((c) => <label key={c.id} className="check"><input type="checkbox" name="cities" value={c.id} /> {c.name_ar}</label>)}
            </div>
          </div>
          <label>العنوان<input name="title" required maxLength={60} /></label>
          <label>النص<textarea name="body" required maxLength={180} /></label>
          <label>الرابط عند الضغط (اختياري)<input name="deep_link" dir="ltr" placeholder="https://munyati.co/c/makeup" /></label>
          <p className="muted small">تصل كإشعار داخل التطبيق وإشعار على الجوال. لا تستخدمي عبارات استعجال مضللة (إرشادات Apple).</p>
          <ConfirmButton message="إرسال الإشعار الآن؟ لا يمكن التراجع.">إرسال</ConfirmButton>
        </form>
        <div className="card">
          <h2 style={{ marginTop: 0 }}>آخر الحملات</h2>
          {(history ?? []).map((h, i) => {
            const a = h.after as { title?: string; audience?: string; recipients?: number };
            return <div key={i} className="small" style={{ marginBottom: 6 }}><b>{a.title}</b> · {a.audience} · {a.recipients} · {fmtDateTime(h.created_at)}</div>;
          })}
        </div>
      </div>
    </>
  );
}
