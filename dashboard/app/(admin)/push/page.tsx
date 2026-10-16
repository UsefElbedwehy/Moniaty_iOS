import { supabaseServer } from "@/lib/supabase/server";
import { Flash } from "@/components/ui";
import { ConfirmButton } from "@/components/ConfirmButton";
import { i18n } from "@/lib/i18n";
import { sendCampaign } from "./actions";

export default async function Push({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const sp = await searchParams;
  const { t, lang, dateTime: fmtDateTime } = await i18n();
  const supabase = await supabaseServer();
  const [{ data: cities }, { data: history }] = await Promise.all([
    supabase.from("cities").select("id, name_ar, name_en").eq("is_active", true).order("sort_order"),
    supabase.from("admin_audit_log").select("after, created_at").eq("entity_type", "campaigns").order("created_at", { ascending: false }).limit(20),
  ]);
  return (
    <>
      <div className="topbar"><h1>{t("الإشعارات", "Push notifications")}</h1></div>
      <Flash sp={sp} />
      <div className="grid two">
        <form className="card stack" action={sendCampaign}>
          <label>{t("الجمهور", "Audience")}
            <select name="audience"><option value="brides">{t("العرائس", "Brides")}</option><option value="providers">{t("مقدّمات الخدمة", "Providers")}</option><option value="all">{t("الجميع", "Everyone")}</option></select>
          </label>
          <div>
            <div className="small muted">{t("المدن (بدون اختيار = كل المدن)", "Cities (none selected = all cities)")}</div>
            <div style={{ display: "flex", gap: 12, flexWrap: "wrap" }}>
              {(cities ?? []).map((c) => <label key={c.id} className="check"><input type="checkbox" name="cities" value={c.id} /> {lang === "ar" ? c.name_ar : c.name_en}</label>)}
            </div>
          </div>
          <label>{t("العنوان", "Title")}<input name="title" required maxLength={60} /></label>
          <label>{t("النص", "Message")}<textarea name="body" required maxLength={180} /></label>
          <label>{t("الرابط عند الضغط (اختياري)", "Link on tap (optional)")}<input name="deep_link" dir="ltr" placeholder="https://munyati.co/c/makeup" /></label>
          <p className="muted small">{t("تصل كإشعار داخل التطبيق وإشعار على الجوال. لا تستخدمي عبارات استعجال مضللة (إرشادات Apple).", "Arrives as an in-app and a push notification, sent as written (write it in the audience's language). No misleading urgency (Apple guidelines).")}</p>
          <ConfirmButton message={t("إرسال الإشعار الآن؟ لا يمكن التراجع.", "Send the notification now? This can't be undone.")}>{t("إرسال", "Send")}</ConfirmButton>
        </form>
        <div className="card">
          <h2 style={{ marginTop: 0 }}>{t("آخر الحملات", "Recent campaigns")}</h2>
          {(history ?? []).map((h, i) => {
            const a = h.after as { title?: string; audience?: string; recipients?: number };
            return <div key={i} className="small" style={{ marginBottom: 6 }}><b>{a.title}</b> · {a.audience} · {a.recipients} · {fmtDateTime(h.created_at)}</div>;
          })}
        </div>
      </div>
    </>
  );
}
