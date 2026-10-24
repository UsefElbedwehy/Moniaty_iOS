import { supabaseServer } from "@/lib/supabase/server";
import { RecordActions } from "@/components/RecordActions";
import { isOwner } from "@/lib/admin";
import { Flash } from "@/components/ui";
import { i18n } from "@/lib/i18n";
import { saveCategory, saveCity } from "./actions";

type City = { id: string; name_ar: string; name_en: string; lat: number | null; lng: number | null; is_active: boolean; sort_order: number };
type Category = { id: string; name_ar: string; name_en: string; icon_symbol: string | null; icon_url: string | null;
  price_hint_ar: string | null; price_hint_en: string | null; is_active: boolean; sort_order: number;
  allows_parallel_bookings: boolean; is_store_category: boolean };

async function CityForm({ c }: { c?: City }) {
  const { t } = await i18n();
  return (
    <form className="inline" action={saveCity} style={{ padding: "8px 0", borderBottom: "1px solid var(--border)" }}>
      <input name="id" defaultValue={c?.id} placeholder={t("المعرّف (dammam)", "ID (dammam)")} required readOnly={!!c} dir="ltr" style={{ width: 120 }} />
      <input name="name_ar" defaultValue={c?.name_ar} placeholder={t("الاسم", "Arabic name")} required style={{ width: 120 }} />
      <input name="name_en" defaultValue={c?.name_en} placeholder={t("Name", "English name")} required dir="ltr" style={{ width: 120 }} />
      <input name="lat" defaultValue={c?.lat ?? ""} placeholder="lat" dir="ltr" style={{ width: 90 }} />
      <input name="lng" defaultValue={c?.lng ?? ""} placeholder="lng" dir="ltr" style={{ width: 90 }} />
      <input name="sort_order" type="number" defaultValue={c?.sort_order ?? 0} style={{ width: 64 }} title={t("الترتيب", "Order")} />
      <label className="check"><input type="checkbox" name="is_active" defaultChecked={c?.is_active ?? true} /> {t("فعّالة", "Active")}</label>
      <button className={c ? "secondary" : ""}>{c ? t("حفظ", "Save") : t("إضافة", "Add")}</button>
    </form>
  );
}

async function CategoryForm({ c }: { c?: Category }) {
  const { t } = await i18n();
  return (
    <form className="stack card" action={saveCategory} style={{ marginBottom: 10 }}>
      <div className="inline" style={{ display: "flex", gap: 8, flexWrap: "wrap", alignItems: "center" }}>
        {c?.icon_url && <img src={c.icon_url} alt="" style={{ width: 32, height: 32 }} />}
        <input name="id" defaultValue={c?.id} placeholder={t("المعرّف (makeup)", "ID (makeup)")} required readOnly={!!c} dir="ltr" style={{ width: 130 }} />
        <input name="name_ar" defaultValue={c?.name_ar} placeholder={t("الاسم", "Arabic name")} required />
        <input name="name_en" defaultValue={c?.name_en} placeholder={t("Name", "English name")} required dir="ltr" />
        <input name="sort_order" type="number" defaultValue={c?.sort_order ?? 0} style={{ width: 64 }} title={t("الترتيب", "Order")} />
      </div>
      <div className="inline" style={{ display: "flex", gap: 8, flexWrap: "wrap", alignItems: "center" }}>
        <input name="price_hint_ar" defaultValue={c?.price_hint_ar ?? ""} placeholder={t("نطاق السعر للعرض", "Arabic price hint")} />
        <input name="price_hint_en" defaultValue={c?.price_hint_en ?? ""} placeholder={t("Price hint", "English price hint")} dir="ltr" />
        <input name="icon_symbol" defaultValue={c?.icon_symbol ?? ""} placeholder="SF Symbol" dir="ltr" style={{ width: 140 }} />
        <input type="hidden" name="icon_url" value={c?.icon_url ?? ""} />
        <label>{t("أيقونة جديدة (PNG/SVG)", "New icon (PNG/SVG)")}<input type="file" name="icon_file" accept="image/png,image/svg+xml" /></label>
      </div>
      <div style={{ display: "flex", gap: 16, flexWrap: "wrap", alignItems: "center" }}>
        <label className="check"><input type="checkbox" name="is_active" defaultChecked={c?.is_active ?? true} /> {t("فعّال", "Active")}</label>
        <label className="check"><input type="checkbox" name="allows_parallel_bookings" defaultChecked={c?.allows_parallel_bookings ?? false} /> {t("يسمح بأكثر من حجز نشط", "Allows parallel bookings")}</label>
        <label className="check"><input type="checkbox" name="is_store_category" defaultChecked={c?.is_store_category ?? false} /> {t("قسم متاجر", "Store category")}</label>
        <button className={c ? "secondary" : ""}>{c ? t("حفظ", "Save") : t("إضافة قسم", "Add category")}</button>
      </div>
    </form>
  );
}

export default async function Catalog({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const sp = await searchParams;
  const { t } = await i18n();
  const supabase = await supabaseServer();
  const [cities, categories] = await Promise.all([
    supabase.from("cities").select("*").is("archived_at", null).order("sort_order"),
    supabase.from("categories").select("*").is("archived_at", null).order("sort_order"),
  ]);
  const owner = await isOwner();
  return (
    <>
      <div className="topbar"><h1>{t("المدن والأقسام", "Cities & categories")}</h1></div>
      <Flash sp={sp} />
      <div className="card">
        <h2 style={{ marginTop: 0 }}>{t("المدن", "Cities")}</h2>
        {((cities.data ?? []) as City[]).map((c) => (
          <div key={c.id} className="record-block"><CityForm c={c} /><RecordActions entity="city" id={c.id} back="/catalog" isOwner={owner} edit={false} /></div>
        ))}
        <h2>{t("مدينة جديدة", "New city")}</h2>
        <CityForm />
      </div>
      <h2>{t("الأقسام", "Categories")}</h2>
      <p className="muted">{t("«يسمح بأكثر من حجز نشط» يستثني القسم من قاعدة حجز واحد لكل قسم (القرار ٥). الأيقونة الجديدة تظهر في التطبيق دون تحديث.", "“Allows parallel bookings” exempts the category from the one-active-booking-per-category rule (decision 5). A new icon shows in the app without an update.")}</p>
      {((categories.data ?? []) as Category[]).map((c) => (
        <div key={c.id} className="record-block"><CategoryForm c={c} /><RecordActions entity="category" id={c.id} back="/catalog" isOwner={owner} edit={false} /></div>
      ))}
      <h2>{t("قسم جديد", "New category")}</h2>
      <CategoryForm />
    </>
  );
}
