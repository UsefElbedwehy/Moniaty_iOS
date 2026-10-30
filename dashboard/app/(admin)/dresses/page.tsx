import Link from "next/link";
import { supabaseServer } from "@/lib/supabase/server";
import { Flash } from "@/components/ui";
import { ConfirmButton } from "@/components/ConfirmButton";
import { i18n } from "@/lib/i18n";
import { saveDress, renewDress, deleteDress, saveDressNotice } from "./actions";

type Dress = { id: string; kind: string; image_url: string; price: number; contact_phone: string; starts_on: string; is_active: boolean };
type Notice = { price?: number; days?: number; phone?: string | null };

const KINDS = ["wedding", "jalwa", "evening"] as const;

/** "yyyy-mm-dd" + n days. */
const addDays = (day: string, n: number) => new Date(new Date(`${day}T00:00:00Z`).getTime() + n * 86_400_000).toISOString().slice(0, 10);
const today = () => new Date(Date.now() + 3 * 3600_000).toISOString().slice(0, 10);
/** +9665XXXXXXXX → 05XXXXXXXX. */
const local = (phone: string | null | undefined) => (phone?.startsWith("+966") ? `0${phone.slice(4)}` : phone ?? "");

async function DressForm({ d, kind }: { d?: Dress; kind: string }) {
  const { t } = await i18n();
  const kindName: Record<string, string> = { wedding: t("فساتين زفاف", "Wedding dresses"), jalwa: t("فساتين جلوات", "Jalwa dresses"), evening: t("فساتين سهرة", "Evening dresses") };
  const ends = d ? addDays(d.starts_on, 29) : null;
  const status = !d ? null
    : !d.is_active ? t("مخفي", "Hidden")
    : d.starts_on > today() ? t(`يبدأ ${d.starts_on}`, `Starts ${d.starts_on}`)
    : ends! < today() ? t(`انتهى في ${ends}`, `Ended ${ends}`)
    : t(`معروض حتى ${ends}`, `Listed until ${ends}`);
  const live = d && d.is_active && d.starts_on <= today() && ends! >= today();
  return (
    <form className="card stack" action={saveDress}>
      <input type="hidden" name="id" value={d?.id ?? ""} />
      <input type="hidden" name="image_url" value={d?.image_url ?? ""} />
      <div style={{ display: "flex", gap: 16, flexWrap: "wrap", alignItems: "flex-start" }}>
        {d?.image_url && <img src={d.image_url} alt="" style={{ width: 120, height: 160, objectFit: "cover", borderRadius: 12 }} />}
        <div className="stack" style={{ flex: 1, minWidth: 240 }}>
          {status && <span className={`badge ${live ? "good" : "bad"}`} style={{ alignSelf: "flex-start" }}>{status}</span>}
          <div style={{ display: "flex", gap: 12, flexWrap: "wrap" }}>
            <label>{t("القائمة", "List")}
              <select name="kind" defaultValue={d?.kind ?? kind}>
                {KINDS.map((k) => <option key={k} value={k}>{kindName[k]}</option>)}
              </select>
            </label>
            <label>{t("السعر (ر.س)", "Price (SAR)")}<input name="price" type="number" min="0" step="1" defaultValue={d?.price ?? ""} required style={{ width: 120 }} /></label>
            <label>{t("رقم التواصل", "Contact number")}<input name="contact_phone" dir="ltr" defaultValue={local(d?.contact_phone)} placeholder="05XXXXXXXX" required style={{ width: 150 }} /></label>
            <label>{t("بداية العرض", "Listed from")}<input name="starts_on" type="date" dir="ltr" defaultValue={d?.starts_on ?? today()} /></label>
          </div>
          <label>{d ? t("تغيير الصورة (حتى ٣ ميغابايت)", "Change photo (up to 3 MB)") : t("صورة الفستان (حتى ٣ ميغابايت)", "Dress photo (up to 3 MB)")}
            <input type="file" name="image_file" accept="image/jpeg,image/png,image/webp" required={!d} />
          </label>
        </div>
      </div>
      <div className="row">
        <label className="check"><input type="checkbox" name="is_active" defaultChecked={d?.is_active ?? true} /> {t("ظاهر", "Visible")}</label>
        <button className={d ? "secondary" : ""}>{d ? t("حفظ", "Save") : t("إضافة الفستان", "Add dress")}</button>
        {d && <button className="secondary" formAction={renewDress}>{t("تجديد ٣٠ يوماً من اليوم", "Renew 30 days from today")}</button>}
        {d && (
          <ConfirmButton className="danger" formAction={deleteDress} message={t("حذف هذا الفستان؟", "Delete this dress?")}>
            {t("حذف", "Delete")}
          </ConfirmButton>
        )}
      </div>
    </form>
  );
}

export default async function Dresses({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const sp = await searchParams;
  const { t } = await i18n();
  const kind = KINDS.includes(sp.kind as (typeof KINDS)[number]) ? (sp.kind as string) : "wedding";
  const supabase = await supabaseServer();
  const [dresses, config] = await Promise.all([
    supabase.from("dress_listings").select("*").eq("kind", kind).order("starts_on", { ascending: false }).order("created_at", { ascending: false }),
    supabase.from("app_config").select("config").eq("id", 1).single(),
  ]);
  const notice = ((config.data?.config ?? {}) as { dress_listing?: Notice }).dress_listing ?? {};
  const tabs: [string, string][] = [["wedding", t("فساتين زفاف", "Wedding dresses")], ["jalwa", t("فساتين جلوات", "Jalwa dresses")], ["evening", t("فساتين سهرة", "Evening dresses")]];
  return (
    <>
      <div className="topbar"><h1>{t("الفساتين", "Dresses")}</h1></div>
      <Flash sp={sp} />
      <p className="muted">{t(
        "قسم «فساتين» في التطبيق يعرض الفساتين التي تضيفينها هنا فقط، في ثلاث قوائم. لكل فستان صورة وسعر ورقم تواصل صاحبته. يظهر الفستان ٣٠ يوماً من «بداية العرض» ثم يختفي وحده؛ جدّديه عند الدفع مرة أخرى. مقدّمات الخدمة لا يستطعن الإضافة في هذا القسم.",
        "The app's «فساتين» section shows only the dresses you add here, in three lists. Each dress has a photo, a price and its owner's contact number. A dress shows for 30 days from “Listed from”, then hides itself; renew it when the owner pays again. Providers can't add to this section.")}</p>

      <form className="card stack" action={saveDressNotice}>
        <h2 style={{ margin: 0 }}>{t("إعلان عرض الفساتين", "Notice for dress owners")}</h2>
        <p className="muted small">{t(
          "يظهر في أعلى القسم: «اعرضي فستانك للإيجار بـ ٢٠ ريال لمدة شهر» مع زر للتواصل على هذا الرقم (واتساب أو اتصال). اتركي الرقم فارغاً لإخفاء الإعلان.",
          "Shows at the top of the section: “List your dress for rent for SAR 20 a month”, with a button to contact this number (WhatsApp or call). Leave the number empty to hide the notice.")}</p>
        <div className="row">
          <label>{t("سعر العرض لمدة شهر (ر.س)", "Price for a month (SAR)")}<input name="price" type="number" min="0" defaultValue={notice.price ?? 20} style={{ width: 120 }} /></label>
          <label>{t("رقم منيتي للتواصل", "Munyati's contact number")}<input name="phone" dir="ltr" defaultValue={local(notice.phone)} placeholder="05XXXXXXXX" style={{ width: 160 }} /></label>
          <button className="secondary">{t("حفظ", "Save")}</button>
        </div>
      </form>

      <div className="row" style={{ gap: 8 }}>
        {tabs.map(([k, label]) => (
          <Link key={k} href={`/dresses?kind=${k}`} className={`badge ${k === kind ? "brand" : ""}`} style={{ padding: "6px 14px" }}>{label}</Link>
        ))}
      </div>

      <h2>{t("فستان جديد", "New dress")}</h2>
      <DressForm kind={kind} />

      <h2>{t(`الفساتين (${(dresses.data ?? []).length})`, `Dresses (${(dresses.data ?? []).length})`)}</h2>
      {(dresses.data ?? []).length === 0 && <p className="muted">{t("لا توجد فساتين في هذه القائمة بعد.", "No dresses in this list yet.")}</p>}
      {((dresses.data ?? []) as Dress[]).map((d) => <DressForm key={d.id} d={d} kind={kind} />)}
    </>
  );
}
