import { supabaseServer } from "@/lib/supabase/server";
import { Flash } from "@/components/ui";
import { ConfirmButton } from "@/components/ConfirmButton";
import { i18n } from "@/lib/i18n";
import type { LabelMap } from "@/lib/labels";
import { saveRawConfig, saveSettings } from "./actions";

type Config = Record<string, any>; // eslint-disable-line @typescript-eslint/no-explicit-any

const smsLabels: LabelMap = {
  booking_requested: ["طلب حجز جديد (للمزوّدة)", "New booking request (to provider)"], booking_approved: ["الموافقة وموعد الدفع", "Approval and payment deadline"],
  reschedule_proposed: ["اقتراح موعد آخر", "New time proposed"], receipt_submitted: ["رفع الإيصال", "Receipt uploaded"],
  payment_confirmed: ["تأكيد الدفع", "Payment confirmed"], payment_rejected: ["رفض الإيصال", "Receipt rejected"],
  booking_cancelled: ["إلغاء الحجز", "Booking cancelled"], booking_reminder: ["تذكير قبل الموعد", "Appointment reminder"],
  trial_ending: ["قرب نهاية التجربة", "Trial ending soon"], subscription_ending: ["قرب نهاية الاشتراك", "Subscription ending soon"],
  listing_hidden: ["إخفاء الخدمات", "Services hidden"], subscription_started: ["تفعيل الباقة", "Plan activated"],
};

export default async function Settings({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const sp = await searchParams;
  const { t, lang, label, dateTime: fmtDateTime } = await i18n();
  const supabase = await supabaseServer();
  const [{ data }, { data: plans }] = await Promise.all([
    supabase.from("app_config").select("config, updated_at").eq("id", 1).single(),
    supabase.from("subscription_plans").select("id, name_ar, name_en").order("sort_order"),
  ]);
  const c: Config = data?.config ?? {};
  const to = c.timeouts_hours ?? {};
  const contacts = (c.support?.contact_methods ?? []).map((m: { kind: string; value: string }) => `${m.kind}: ${m.value}`).join("\n");

  return (
    <>
      <div className="topbar"><h1>{t("الإعدادات", "Settings")}</h1><span className="muted small">{t("آخر تعديل:", "Last changed:")} {fmtDateTime(data?.updated_at)}</span></div>
      <p className="muted">{t("تصل للتطبيق عند فتحه التالي، دون تحديث من المتجر. كل تعديل يُسجَّل في سجل التعديلات.", "Reaches the app the next time it opens, with no App Store update. Every change is recorded in the audit log.")}</p>
      <Flash sp={sp} />
      <form className="stack" action={saveSettings}>
        <div className="grid two">
          <div className="card stack">
            <h2 style={{ margin: 0 }}>{t("الحجز (القرار ٨)", "Booking (decision 8)")}</h2>
            <div className="grid two">
              <label>{t("مهلة رد المزوّدة (ساعة)", "Provider reply time (hours)")}<input name="t_request" type="number" min={1} defaultValue={to.request ?? 48} /></label>
              <label>{t("مهلة رد العروس على الموعد المقترح", "Bride reply time to a proposed time")}<input name="t_proposal" type="number" min={1} defaultValue={to.proposal ?? 24} /></label>
              <label>{t("مهلة الدفع", "Payment time")}<input name="t_payment" type="number" min={1} defaultValue={to.payment ?? 48} /></label>
              <label>{t("مهلة تأكيد استلام المبلغ", "Time to confirm payment received")}<input name="t_receipt" type="number" min={1} defaultValue={to.receipt_confirmation ?? 48} /></label>
            </div>
            <h2 style={{ margin: 0 }}>{t("الاشتراكات", "Subscriptions")}</h2>
            <div className="grid two">
              <label>{t("أيام الفترة المجانية", "Free trial days")}<input name="trial_days" type="number" min={0} defaultValue={c.trial_days ?? 60} /></label>
              <label>{t("مزايا الفترة المجانية", "Trial plan features")}
                <select name="trial_plan_id" defaultValue={c.trial_plan_id ?? "diamond"}>
                  {(plans ?? []).map((p) => <option key={p.id} value={p.id}>{lang === "ar" ? p.name_ar : p.name_en}</option>)}
                </select>
              </label>
            </div>
          </div>

          <div className="card stack">
            <h2 style={{ margin: 0 }}>{t("التقييمات", "Reviews")}</h2>
            <label className="check"><input type="checkbox" name="reviews_premoderation" defaultChecked={c.reviews_premoderation ?? true} /> {t("مراجعة التقييمات قبل نشرها", "Moderate reviews before publishing")}</label>
            <label>{t("مدة السماح بالتقييم بعد اكتمال الحجز (يوم)", "Review window after completion (days)")}<input name="review_window_days" type="number" min={1} defaultValue={c.review_window_days ?? 30} /></label>
            <label>{t("كلمات محظورة (كلمة في كل سطر؛ التقييم الذي يحتويها يذهب للمراجعة دائماً)", "Banned words (one per line; reviews containing them always go to moderation)")}
              <textarea name="banned_words" defaultValue={(c.banned_words ?? []).join("\n")} />
            </label>
          </div>

          <div className="card stack">
            <h2 style={{ margin: 0 }}>{t("الرسائل النصية (OurSMS)", "Text messages (OurSMS)")}</h2>
            <p className="muted small">{t("الأحداث التي تُرسل أيضاً برسالة نصية، إضافة للإشعار.", "Events that also send a text message, in addition to the notification.")}</p>
            {Object.keys(c.sms_events ?? {}).map((key) => (
              <label key={key} className="check">
                <input type="checkbox" name={`sms_${key}`} defaultChecked={!!c.sms_events[key]} /> {label(smsLabels, key)}
              </label>
            ))}
          </div>

          <div className="card stack">
            <h2 style={{ margin: 0 }}>{t("التطبيق", "App")}</h2>
            <label className="check"><input type="checkbox" name="maintenance" defaultChecked={!!c.feature_flags?.maintenanceMode} /> {t("وضع الصيانة", "Maintenance mode")}</label>
            <div className="grid two">
              <label>{t("أقل إصدار مطلوب", "Minimum required version")}<input name="min_version" dir="ltr" placeholder="1.0.0" defaultValue={c.update?.min_required_version ?? ""} /></label>
              <label>{t("رابط المتجر", "App Store link")}<input name="store_url" dir="ltr" defaultValue={c.update?.store_url ?? ""} /></label>
            </div>
            <label className="check"><input type="checkbox" name="force_update" defaultChecked={!!c.update?.force_update} /> {t("إجبار التحديث", "Force update")}</label>
            <label>{t("رسالة التحديث", "Update message")}<input name="update_message" defaultValue={c.update?.update_message ?? ""} /></label>
            <h2 style={{ margin: 0 }}>{t("شريط العروض في الرئيسية", "Home carousel")}</h2>
            <p className="muted small">{t("شريحتا منيتي الثابتتان تظهران بعد بنرات الإعلانات. أخفيهما ليبقى الشريط للإعلانات فقط؛ إن لم يوجد بنر فعّال يختفي الشريط كاملاً.", "Munyati's two built-in slides show after the ad banners. Hide them to keep the carousel for ads only; with no active banner, the carousel disappears.")}</p>
            <label className="check"><input type="checkbox" name="show_budget_slide" defaultChecked={!c.feature_flags?.hideHomeBudgetSlide} /> {t("إظهار شريحة «احجزي ضمن ميزانيتك»", "Show the “Book within your budget” slide")}</label>
            <label className="check"><input type="checkbox" name="show_discover_slide" defaultChecked={!c.feature_flags?.hideHomeDiscoverSlide} /> {t("إظهار شريحة «مقدّمات خدمة موثّقات في مدينتك»", "Show the “Verified providers in your city” slide")}</label>
            <h2 style={{ margin: 0 }}>{t("الدعم", "Support")}</h2>
            <label>{t("رابط الأسئلة الشائعة", "FAQ link")}<input name="help_center_url" dir="ltr" defaultValue={c.support?.help_center_url ?? ""} /></label>
            <label>{t("وسائل التواصل (سطر لكل وسيلة: email / whatsapp / phone)", "Contact methods (one per line: email / whatsapp / phone)")}
              <textarea name="contacts" dir="ltr" defaultValue={contacts} placeholder={"email: contact@munyati.co\nwhatsapp: +9665XXXXXXXX"} />
            </label>
          </div>
        </div>
        <div><ConfirmButton message={t("حفظ الإعدادات؟ تصل للتطبيقات مباشرة.", "Save settings? They reach the apps right away.")}>{t("حفظ الإعدادات", "Save settings")}</ConfirmButton></div>
      </form>

      <details>
        <summary>{t("متقدم: تعديل JSON كامل", "Advanced: edit the full JSON")}</summary>
        <form className="stack" action={saveRawConfig} style={{ marginTop: 12 }}>
          <textarea name="json" dir="ltr" className="mono" style={{ minHeight: 360 }} defaultValue={JSON.stringify(c, null, 2)} />
          <div><ConfirmButton message={t("استبدال الإعدادات كاملة؟", "Replace all settings?")} className="danger">{t("حفظ JSON", "Save JSON")}</ConfirmButton></div>
        </form>
      </details>
    </>
  );
}
