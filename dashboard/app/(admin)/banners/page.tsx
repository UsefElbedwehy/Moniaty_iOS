import { supabaseServer } from "@/lib/supabase/server";
import { RecordActions } from "@/components/RecordActions";
import { isOwner } from "@/lib/admin";
import { Flash } from "@/components/ui";
import { ConfirmButton } from "@/components/ConfirmButton";
import { i18n } from "@/lib/i18n";
import { saveBanner, deleteBanner } from "./actions";

type Banner = { id: string; title_ar: string; title_en: string; subtitle_ar: string | null; subtitle_en: string | null;
  cta_ar: string | null; cta_en: string | null; image_url: string | null; link_url: string | null; city_ids: string[] | null;
  starts_at: string | null; ends_at: string | null; is_active: boolean; sort_order: number };
type City = { id: string; name_ar: string; name_en: string };

/** An ISO time as a `datetime-local` value in Saudi time. */
const local = (iso: string | null) => (iso ? new Date(new Date(iso).getTime() + 3 * 3600_000).toISOString().slice(0, 16) : "");

async function BannerForm({ b, cities }: { b?: Banner; cities: City[] }) {
  const { t, lang } = await i18n();
  return (
    <form className="stack card" action={saveBanner} style={{ marginBottom: 10 }}>
      <input type="hidden" name="id" value={b?.id ?? ""} />
      <input type="hidden" name="image_url" value={b?.image_url ?? ""} />
      <div style={{ display: "flex", gap: 12, flexWrap: "wrap", alignItems: "flex-start" }}>
        {b?.image_url && <img src={b.image_url} alt="" style={{ width: 160, height: 80, objectFit: "cover", borderRadius: 10 }} />}
        <div className="stack" style={{ flex: 1, minWidth: 260 }}>
          <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
            <input name="title_ar" defaultValue={b?.title_ar} placeholder={t("العنوان", "Arabic title")} required style={{ flex: 1 }} />
            <input name="title_en" defaultValue={b?.title_en} placeholder={t("Title", "English title")} required dir="ltr" style={{ flex: 1 }} />
          </div>
          <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
            <input name="subtitle_ar" defaultValue={b?.subtitle_ar ?? ""} placeholder={t("النص الفرعي", "Arabic subtitle")} style={{ flex: 1 }} />
            <input name="subtitle_en" defaultValue={b?.subtitle_en ?? ""} placeholder={t("Subtitle", "English subtitle")} dir="ltr" style={{ flex: 1 }} />
          </div>
          <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
            <input name="cta_ar" defaultValue={b?.cta_ar ?? ""} placeholder={t("نص الزر (احجزي الآن)", "Arabic button text")} style={{ width: 170 }} />
            <input name="cta_en" defaultValue={b?.cta_en ?? ""} placeholder={t("Button text", "English button text")} dir="ltr" style={{ width: 170 }} />
            <input name="link_url" defaultValue={b?.link_url ?? ""} placeholder="https://munyati.co/c/makeup" dir="ltr" style={{ flex: 1, minWidth: 220 }} />
          </div>
        </div>
      </div>
      <div style={{ display: "flex", gap: 12, flexWrap: "wrap", alignItems: "center" }}>
        <label>{t("صورة جديدة (عرض ٢:١، حتى ١ ميغابايت)", "New image (2:1, up to 1 MB)")}<input type="file" name="image_file" accept="image/jpeg,image/png,image/webp" /></label>
        <label>{t("يبدأ", "Starts")} <input type="datetime-local" name="starts_at" defaultValue={local(b?.starts_at ?? null)} dir="ltr" /></label>
        <label>{t("ينتهي", "Ends")} <input type="datetime-local" name="ends_at" defaultValue={local(b?.ends_at ?? null)} dir="ltr" /></label>
      </div>
      <div style={{ display: "flex", gap: 16, flexWrap: "wrap", alignItems: "center" }}>
        <span className="muted small">{t("المدن (بدون اختيار = كل المدن):", "Cities (none = all):")}</span>
        {cities.map((c) => (
          <label key={c.id} className="check">
            <input type="checkbox" name="city_ids" value={c.id} defaultChecked={b?.city_ids?.includes(c.id) ?? false} /> {lang === "ar" ? c.name_ar : c.name_en}
          </label>
        ))}
      </div>
      <div style={{ display: "flex", gap: 16, flexWrap: "wrap", alignItems: "center" }}>
        <input name="sort_order" type="number" defaultValue={b?.sort_order ?? 0} style={{ width: 64 }} title={t("الترتيب", "Order")} />
        <label className="check"><input type="checkbox" name="is_active" defaultChecked={b?.is_active ?? true} /> {t("فعّال", "Active")}</label>
        <button className={b ? "secondary" : ""}>{b ? t("حفظ", "Save") : t("إضافة بنر", "Add banner")}</button>
        {b && (
          <ConfirmButton className="danger" formAction={deleteBanner} message={t("حذف هذا البنر؟", "Delete this banner?")}>
            {t("حذف", "Delete")}
          </ConfirmButton>
        )}
      </div>
    </form>
  );
}

export default async function Banners({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const sp = await searchParams;
  const { t } = await i18n();
  const supabase = await supabaseServer();
  const [banners, cities] = await Promise.all([
    supabase.from("home_banners").select("*").is("archived_at", null).order("sort_order").order("created_at", { ascending: false }),
    supabase.from("cities").select("id, name_ar, name_en").order("sort_order"),
  ]);
  const cityList = (cities.data ?? []) as City[];
  const owner = await isOwner();
  return (
    <>
      <div className="topbar"><h1>{t("بنرات الرئيسية", "Home banners")}</h1></div>
      <Flash sp={sp} />
      <p className="muted">{t(
        "تظهر البنرات الفعّالة أولاً في شريط العروض بالصفحة الرئيسية للعروس، ثم شرائح منيتي الثابتة. الرابط اختياري: رابط داخل التطبيق مثل https://munyati.co/c/makeup (قسم) أو /s/<id> (خدمة) أو /p/<id> (مقدّمة خدمة)، أو رابط خارجي.",
        "Active banners show first in the bride's Home carousel, followed by Munyati's built-in slides. The link is optional: an app link such as https://munyati.co/c/makeup (category), /s/<id> (service) or /p/<id> (provider), or an outside link.")}</p>
      {((banners.data ?? []) as Banner[]).map((b) => (
        <div key={b.id} className="record-block">
          <BannerForm b={b} cities={cityList} />
          <RecordActions entity="banner" id={b.id} back="/banners" isOwner={owner} edit={false} />
        </div>
      ))}
      <h2>{t("بنر جديد", "New banner")}</h2>
      <BannerForm cities={cityList} />
    </>
  );
}
