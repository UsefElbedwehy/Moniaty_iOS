import { ConfirmButton } from "@/components/ConfirmButton";
import { i18n } from "@/lib/i18n";
import { reviewProvider } from "@/app/(admin)/providers/actions";

/** One-click Approve (optionally with the verified badge) or Reject with a reason. */
export async function ProviderDecision({ id, back, compact = false }: { id: string; back: string; compact?: boolean }) {
  const { t } = await i18n();
  return (
    <form className="inline decision" action={reviewProvider}>
      <input type="hidden" name="id" value={id} />
      <input type="hidden" name="back_path" value={back} />
      {!compact && <label className="check small"><input type="checkbox" name="verified" /> {t("موثّقة", "Verified")}</label>}
      <ConfirmButton message={t("تفعيل مقدّمة الخدمة؟ ستظهر خدماتها للعرائس وتبدأ فترتها المجانية.", "Approve this provider? Their services go live and the free trial starts.")}
        formAction={async (form: FormData) => { "use server"; form.set("status", "approved"); return reviewProvider(form); }}>
        {t("قبول", "Approve")}
      </ConfirmButton>
      {!compact && <input name="note" placeholder={t("سبب الرفض (يظهر لها)", "Reason if rejecting (she sees it)")} />}
      <ConfirmButton className="danger" message={t("رفض الطلب وإشعارها؟", "Reject and notify her?")}
        formAction={async (form: FormData) => { "use server"; form.set("status", "rejected"); return reviewProvider(form); }}>
        {t("رفض", "Reject")}
      </ConfirmButton>
    </form>
  );
}
