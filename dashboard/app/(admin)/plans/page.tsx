import { supabaseServer } from "@/lib/supabase/server";
import { Flash } from "@/components/ui";
import { ConfirmButton } from "@/components/ConfirmButton";
import { savePlan } from "./actions";

type Plan = Record<string, unknown> & { id: string; features_ar: string[]; features_en: string[] };

export default async function Plans({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const sp = await searchParams;
  const supabase = await supabaseServer();
  const { data } = await supabase.from("subscription_plans").select("*").order("sort_order");
  const plans = (data ?? []) as Plan[];
  const v = (p: Plan, k: string) => (p[k] == null ? "" : String(p[k]));

  return (
    <>
      <div className="topbar"><h1>الباقات</h1></div>
      <p className="muted">التغييرات تظهر في التطبيق فوراً. خفض الحدود لا يحذف شيئاً: الخدمات الزائدة تُوقف مؤقتاً عند بداية الفترة التالية، وتختار مقدّمة الخدمة ما يبقى ظاهراً.</p>
      <Flash sp={sp} />
      <div className="grid two">
        {plans.map((p) => (
          <form key={p.id} className="card stack" action={savePlan}>
            <input type="hidden" name="id" value={p.id} />
            <h2 style={{ margin: 0 }}>{v(p, "name_ar")} <span className="mono muted">{p.id}</span></h2>
            <div className="grid two">
              <label>الاسم (عربي)<input name="name_ar" defaultValue={v(p, "name_ar")} required /></label>
              <label>الاسم (إنجليزي)<input name="name_en" defaultValue={v(p, "name_en")} required dir="ltr" /></label>
              <label>الوصف (عربي)<input name="description_ar" defaultValue={v(p, "description_ar")} /></label>
              <label>الوصف (إنجليزي)<input name="description_en" defaultValue={v(p, "description_en")} dir="ltr" /></label>
              <label>السعر الشهري (ر.س)<input name="price_sar" type="number" step="0.01" min={0} defaultValue={v(p, "price_sar")} /></label>
              <label>الترتيب<input name="sort_order" type="number" defaultValue={v(p, "sort_order")} /></label>
              <label>عدد الخدمات النشطة<input name="max_services" type="number" min={0} defaultValue={v(p, "max_services")} /></label>
              <label>عدد المتاجر<input name="max_stores" type="number" min={0} defaultValue={v(p, "max_stores")} /></label>
              <label>الصور لكل خدمة<input name="max_photos_per_service" type="number" min={1} defaultValue={v(p, "max_photos_per_service")} /></label>
              <label>تعزيز الظهور (٠ عادي)<input name="search_boost" type="number" min={0} max={10} defaultValue={v(p, "search_boost")} /></label>
              <label>الإحصائيات
                <select name="insights_level" defaultValue={v(p, "insights_level")}>
                  <option value="basic">أساسية</option><option value="full">كاملة</option><option value="export">كاملة + تصدير</option>
                </select>
              </label>
            </div>
            <label>المزايا بالعربي (سطر لكل ميزة)<textarea name="features_ar" defaultValue={(p.features_ar ?? []).join("\n")} /></label>
            <label>المزايا بالإنجليزي<textarea name="features_en" dir="ltr" defaultValue={(p.features_en ?? []).join("\n")} /></label>
            <div style={{ display: "flex", gap: 16, flexWrap: "wrap" }}>
              <label className="check"><input type="checkbox" name="is_featured" defaultChecked={!!p.is_featured} /> شارة «مميّزة»</label>
              <label className="check"><input type="checkbox" name="is_recommended" defaultChecked={!!p.is_recommended} /> «الأكثر اختياراً»</label>
              <label className="check"><input type="checkbox" name="is_active" defaultChecked={!!p.is_active} /> ظاهرة للاشتراك</label>
            </div>
            <ConfirmButton message="حفظ الباقة؟ تظهر التغييرات للمزوّدات فوراً.">حفظ</ConfirmButton>
          </form>
        ))}
      </div>
    </>
  );
}
