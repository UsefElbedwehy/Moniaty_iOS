import { supabaseServer } from "@/lib/supabase/server";
import { RecordActions } from "@/components/RecordActions";
import { isOwner } from "@/lib/admin";
import { Flash } from "@/components/ui";
import { ConfirmButton } from "@/components/ConfirmButton";
import { i18n } from "@/lib/i18n";
import { savePlan } from "./actions";

type Plan = Record<string, unknown> & { id: string; features_ar: string[]; features_en: string[] };

export default async function Plans({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const sp = await searchParams;
  const { t, lang } = await i18n();
  const supabase = await supabaseServer();
  const { data } = await supabase.from("subscription_plans").select("*").is("archived_at", null).order("sort_order");
  const plans = (data ?? []) as Plan[];
  const v = (p: Plan, k: string) => (p[k] == null ? "" : String(p[k]));

  const owner = await isOwner();
  return (
    <>
      <div className="topbar"><h1>{t("الباقات", "Plans")}</h1></div>
      <p className="muted">{t("التغييرات تظهر في التطبيق فوراً. خفض الحدود لا يحذف شيئاً: الخدمات الزائدة تُوقف مؤقتاً عند بداية الفترة التالية، وتختار مقدّمة الخدمة ما يبقى ظاهراً.", "Changes show in the app immediately. Lowering a limit deletes nothing: extra services are paused from the next period, and the provider chooses which stay live.")}</p>
      <Flash sp={sp} />
      <div className="grid two">
        {plans.map((p) => (
          <div key={p.id} className="record-block">
          <form className="card stack" action={savePlan}>
            <input type="hidden" name="id" value={p.id} />
            <h2 style={{ margin: 0 }}>{v(p, lang === "ar" ? "name_ar" : "name_en")} <span className="mono muted">{p.id}</span></h2>
            <div className="grid two">
              <label>{t("الاسم (عربي)", "Name (Arabic)")}<input name="name_ar" defaultValue={v(p, "name_ar")} required /></label>
              <label>{t("الاسم (إنجليزي)", "Name (English)")}<input name="name_en" defaultValue={v(p, "name_en")} required dir="ltr" /></label>
              <label>{t("الوصف (عربي)", "Description (Arabic)")}<input name="description_ar" defaultValue={v(p, "description_ar")} /></label>
              <label>{t("الوصف (إنجليزي)", "Description (English)")}<input name="description_en" defaultValue={v(p, "description_en")} dir="ltr" /></label>
              <label>{t("السعر الشهري (ر.س)", "Monthly price (SAR)")}<input name="price_sar" type="number" step="0.01" min={0} defaultValue={v(p, "price_sar")} /></label>
              <label>{t("الترتيب", "Order")}<input name="sort_order" type="number" defaultValue={v(p, "sort_order")} /></label>
              <label>{t("عدد الخدمات النشطة", "Active services")}<input name="max_services" type="number" min={0} defaultValue={v(p, "max_services")} /></label>
              <label>{t("عدد المتاجر", "Stores")}<input name="max_stores" type="number" min={0} defaultValue={v(p, "max_stores")} /></label>
              <label>{t("الصور لكل خدمة", "Photos per service")}<input name="max_photos_per_service" type="number" min={1} defaultValue={v(p, "max_photos_per_service")} /></label>
              <label>{t("تعزيز الظهور (٠ عادي)", "Search boost (0 = normal)")}<input name="search_boost" type="number" min={0} max={10} defaultValue={v(p, "search_boost")} /></label>
              <label>{t("الإحصائيات", "Insights")}
                <select name="insights_level" defaultValue={v(p, "insights_level")}>
                  <option value="basic">{t("أساسية", "Basic")}</option><option value="full">{t("كاملة", "Full")}</option><option value="export">{t("كاملة + تصدير", "Full + export")}</option>
                </select>
              </label>
            </div>
            <label>{t("المزايا بالعربي (سطر لكل ميزة)", "Features in Arabic (one per line)")}<textarea name="features_ar" defaultValue={(p.features_ar ?? []).join("\n")} /></label>
            <label>{t("المزايا بالإنجليزي", "Features in English")}<textarea name="features_en" dir="ltr" defaultValue={(p.features_en ?? []).join("\n")} /></label>
            <div style={{ display: "flex", gap: 16, flexWrap: "wrap" }}>
              <label className="check"><input type="checkbox" name="is_featured" defaultChecked={!!p.is_featured} /> {t("شارة «مميّزة»", "“Featured” badge")}</label>
              <label className="check"><input type="checkbox" name="is_recommended" defaultChecked={!!p.is_recommended} /> {t("«الأكثر اختياراً»", "“Most popular”")}</label>
              <label className="check"><input type="checkbox" name="is_active" defaultChecked={!!p.is_active} /> {t("ظاهرة للاشتراك", "Available to subscribe")}</label>
            </div>
            <ConfirmButton message={t("حفظ الباقة؟ تظهر التغييرات للمزوّدات فوراً.", "Save the plan? Providers see the changes immediately.")}>{t("حفظ", "Save")}</ConfirmButton>
          </form>
          <RecordActions entity="plan" id={p.id} back="/plans" isOwner={owner} edit={false} />
          </div>
        ))}
      </div>
    </>
  );
}
