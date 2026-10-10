import { supabaseServer } from "@/lib/supabase/server";
import { Flash } from "@/components/ui";
import { saveCategory, saveCity } from "./actions";

type City = { id: string; name_ar: string; name_en: string; lat: number | null; lng: number | null; is_active: boolean; sort_order: number };
type Category = { id: string; name_ar: string; name_en: string; icon_symbol: string | null; icon_url: string | null;
  price_hint_ar: string | null; price_hint_en: string | null; is_active: boolean; sort_order: number;
  allows_parallel_bookings: boolean; is_store_category: boolean };

function CityForm({ c }: { c?: City }) {
  return (
    <form className="inline" action={saveCity} style={{ padding: "8px 0", borderBottom: "1px solid var(--border)" }}>
      <input name="id" defaultValue={c?.id} placeholder="المعرّف (dammam)" required readOnly={!!c} dir="ltr" style={{ width: 120 }} />
      <input name="name_ar" defaultValue={c?.name_ar} placeholder="الاسم" required style={{ width: 120 }} />
      <input name="name_en" defaultValue={c?.name_en} placeholder="Name" required dir="ltr" style={{ width: 120 }} />
      <input name="lat" defaultValue={c?.lat ?? ""} placeholder="lat" dir="ltr" style={{ width: 90 }} />
      <input name="lng" defaultValue={c?.lng ?? ""} placeholder="lng" dir="ltr" style={{ width: 90 }} />
      <input name="sort_order" type="number" defaultValue={c?.sort_order ?? 0} style={{ width: 64 }} title="الترتيب" />
      <label className="check"><input type="checkbox" name="is_active" defaultChecked={c?.is_active ?? true} /> فعّالة</label>
      <button className={c ? "secondary" : ""}>{c ? "حفظ" : "إضافة"}</button>
    </form>
  );
}

function CategoryForm({ c }: { c?: Category }) {
  return (
    <form className="stack card" action={saveCategory} style={{ marginBottom: 10 }}>
      <div className="inline" style={{ display: "flex", gap: 8, flexWrap: "wrap", alignItems: "center" }}>
        {c?.icon_url && <img src={c.icon_url} alt="" style={{ width: 32, height: 32 }} />}
        <input name="id" defaultValue={c?.id} placeholder="المعرّف (makeup)" required readOnly={!!c} dir="ltr" style={{ width: 130 }} />
        <input name="name_ar" defaultValue={c?.name_ar} placeholder="الاسم" required />
        <input name="name_en" defaultValue={c?.name_en} placeholder="Name" required dir="ltr" />
        <input name="sort_order" type="number" defaultValue={c?.sort_order ?? 0} style={{ width: 64 }} title="الترتيب" />
      </div>
      <div className="inline" style={{ display: "flex", gap: 8, flexWrap: "wrap", alignItems: "center" }}>
        <input name="price_hint_ar" defaultValue={c?.price_hint_ar ?? ""} placeholder="نطاق السعر للعرض" />
        <input name="price_hint_en" defaultValue={c?.price_hint_en ?? ""} placeholder="Price hint" dir="ltr" />
        <input name="icon_symbol" defaultValue={c?.icon_symbol ?? ""} placeholder="SF Symbol" dir="ltr" style={{ width: 140 }} />
        <input type="hidden" name="icon_url" value={c?.icon_url ?? ""} />
        <label>أيقونة جديدة (PNG/SVG)<input type="file" name="icon_file" accept="image/png,image/svg+xml" /></label>
      </div>
      <div style={{ display: "flex", gap: 16, flexWrap: "wrap", alignItems: "center" }}>
        <label className="check"><input type="checkbox" name="is_active" defaultChecked={c?.is_active ?? true} /> فعّال</label>
        <label className="check"><input type="checkbox" name="allows_parallel_bookings" defaultChecked={c?.allows_parallel_bookings ?? false} /> يسمح بأكثر من حجز نشط</label>
        <label className="check"><input type="checkbox" name="is_store_category" defaultChecked={c?.is_store_category ?? false} /> قسم متاجر</label>
        <button className={c ? "secondary" : ""}>{c ? "حفظ" : "إضافة قسم"}</button>
      </div>
    </form>
  );
}

export default async function Catalog({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const sp = await searchParams;
  const supabase = await supabaseServer();
  const [cities, categories] = await Promise.all([
    supabase.from("cities").select("*").order("sort_order"),
    supabase.from("categories").select("*").order("sort_order"),
  ]);
  return (
    <>
      <div className="topbar"><h1>المدن والأقسام</h1></div>
      <Flash sp={sp} />
      <div className="card">
        <h2 style={{ marginTop: 0 }}>المدن</h2>
        {((cities.data ?? []) as City[]).map((c) => <CityForm key={c.id} c={c} />)}
        <h2>مدينة جديدة</h2>
        <CityForm />
      </div>
      <h2>الأقسام</h2>
      <p className="muted">«يسمح بأكثر من حجز نشط» يستثني القسم من قاعدة حجز واحد لكل قسم (القرار ٥). الأيقونة الجديدة تظهر في التطبيق دون تحديث.</p>
      {((categories.data ?? []) as Category[]).map((c) => <CategoryForm key={c.id} c={c} />)}
      <h2>قسم جديد</h2>
      <CategoryForm />
    </>
  );
}
