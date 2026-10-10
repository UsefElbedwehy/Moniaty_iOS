import { supabaseServer } from "@/lib/supabase/server";
import { Flash } from "@/components/ui";
import { ConfirmButton } from "@/components/ConfirmButton";
import { fmtDateTime } from "@/lib/format";
import { saveRawConfig, saveSettings } from "./actions";

type Config = Record<string, any>; // eslint-disable-line @typescript-eslint/no-explicit-any

const smsLabels: Record<string, string> = {
  booking_requested: "طلب حجز جديد (للمزوّدة)", booking_approved: "الموافقة وموعد الدفع", reschedule_proposed: "اقتراح موعد آخر",
  receipt_submitted: "رفع الإيصال", payment_confirmed: "تأكيد الدفع", payment_rejected: "رفض الإيصال",
  booking_cancelled: "إلغاء الحجز", booking_reminder: "تذكير قبل الموعد", trial_ending: "قرب نهاية التجربة",
  subscription_ending: "قرب نهاية الاشتراك", listing_hidden: "إخفاء الخدمات", subscription_started: "تفعيل الباقة",
};

export default async function Settings({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const sp = await searchParams;
  const supabase = await supabaseServer();
  const [{ data }, { data: plans }] = await Promise.all([
    supabase.from("app_config").select("config, updated_at").eq("id", 1).single(),
    supabase.from("subscription_plans").select("id, name_ar").order("sort_order"),
  ]);
  const c: Config = data?.config ?? {};
  const t = c.timeouts_hours ?? {};
  const contacts = (c.support?.contact_methods ?? []).map((m: { kind: string; value: string }) => `${m.kind}: ${m.value}`).join("\n");

  return (
    <>
      <div className="topbar"><h1>الإعدادات</h1><span className="muted small">آخر تعديل: {fmtDateTime(data?.updated_at)}</span></div>
      <p className="muted">تصل للتطبيق عند فتحه التالي، دون تحديث من المتجر. كل تعديل يُسجَّل في سجل التعديلات.</p>
      <Flash sp={sp} />
      <form className="stack" action={saveSettings}>
        <div className="grid two">
          <div className="card stack">
            <h2 style={{ margin: 0 }}>الحجز (القرار ٨)</h2>
            <div className="grid two">
              <label>مهلة رد المزوّدة (ساعة)<input name="t_request" type="number" min={1} defaultValue={t.request ?? 48} /></label>
              <label>مهلة رد العروس على الموعد المقترح<input name="t_proposal" type="number" min={1} defaultValue={t.proposal ?? 24} /></label>
              <label>مهلة الدفع<input name="t_payment" type="number" min={1} defaultValue={t.payment ?? 48} /></label>
              <label>مهلة تأكيد استلام المبلغ<input name="t_receipt" type="number" min={1} defaultValue={t.receipt_confirmation ?? 48} /></label>
            </div>
            <h2 style={{ margin: 0 }}>الاشتراكات</h2>
            <div className="grid two">
              <label>أيام الفترة المجانية<input name="trial_days" type="number" min={0} defaultValue={c.trial_days ?? 60} /></label>
              <label>مزايا الفترة المجانية
                <select name="trial_plan_id" defaultValue={c.trial_plan_id ?? "diamond"}>
                  {(plans ?? []).map((p) => <option key={p.id} value={p.id}>{p.name_ar}</option>)}
                </select>
              </label>
            </div>
          </div>

          <div className="card stack">
            <h2 style={{ margin: 0 }}>التقييمات</h2>
            <label className="check"><input type="checkbox" name="reviews_premoderation" defaultChecked={c.reviews_premoderation ?? true} /> مراجعة التقييمات قبل نشرها</label>
            <label>مدة السماح بالتقييم بعد اكتمال الحجز (يوم)<input name="review_window_days" type="number" min={1} defaultValue={c.review_window_days ?? 30} /></label>
            <label>كلمات محظورة (كلمة في كل سطر؛ التقييم الذي يحتويها يذهب للمراجعة دائماً)
              <textarea name="banned_words" defaultValue={(c.banned_words ?? []).join("\n")} />
            </label>
          </div>

          <div className="card stack">
            <h2 style={{ margin: 0 }}>الرسائل النصية (OurSMS)</h2>
            <p className="muted small">الأحداث التي تُرسل أيضاً برسالة نصية، إضافة للإشعار.</p>
            {Object.keys(c.sms_events ?? {}).map((key) => (
              <label key={key} className="check">
                <input type="checkbox" name={`sms_${key}`} defaultChecked={!!c.sms_events[key]} /> {smsLabels[key] ?? key}
              </label>
            ))}
          </div>

          <div className="card stack">
            <h2 style={{ margin: 0 }}>التطبيق</h2>
            <label className="check"><input type="checkbox" name="maintenance" defaultChecked={!!c.feature_flags?.maintenanceMode} /> وضع الصيانة</label>
            <div className="grid two">
              <label>أقل إصدار مطلوب<input name="min_version" dir="ltr" placeholder="1.0.0" defaultValue={c.update?.min_required_version ?? ""} /></label>
              <label>رابط المتجر<input name="store_url" dir="ltr" defaultValue={c.update?.store_url ?? ""} /></label>
            </div>
            <label className="check"><input type="checkbox" name="force_update" defaultChecked={!!c.update?.force_update} /> إجبار التحديث</label>
            <label>رسالة التحديث<input name="update_message" defaultValue={c.update?.update_message ?? ""} /></label>
            <h2 style={{ margin: 0 }}>الدعم</h2>
            <label>رابط الأسئلة الشائعة<input name="help_center_url" dir="ltr" defaultValue={c.support?.help_center_url ?? ""} /></label>
            <label>وسائل التواصل (سطر لكل وسيلة: email / whatsapp / phone)
              <textarea name="contacts" dir="ltr" defaultValue={contacts} placeholder={"email: contact@munyati.co\nwhatsapp: +9665XXXXXXXX"} />
            </label>
          </div>
        </div>
        <div><ConfirmButton message="حفظ الإعدادات؟ تصل للتطبيقات مباشرة.">حفظ الإعدادات</ConfirmButton></div>
      </form>

      <details style={{ marginTop: 24 }}>
        <summary>متقدم: تعديل JSON كامل</summary>
        <form className="stack" action={saveRawConfig} style={{ marginTop: 10 }}>
          <textarea name="json" dir="ltr" className="mono" style={{ minHeight: 360 }} defaultValue={JSON.stringify(c, null, 2)} />
          <div><ConfirmButton message="استبدال الإعدادات كاملة؟" className="danger">حفظ JSON</ConfirmButton></div>
        </form>
      </details>
    </>
  );
}
