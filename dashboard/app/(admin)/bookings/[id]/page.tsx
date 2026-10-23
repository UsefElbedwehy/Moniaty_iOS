import Link from "next/link";
import { notFound } from "next/navigation";
import { supabaseServer } from "@/lib/supabase/server";
import { Badge, Flash } from "@/components/ui";
import { ConfirmButton } from "@/components/ConfirmButton";
import { i18n } from "@/lib/i18n";
import { bookingStatus, disputeReason, party } from "@/lib/labels";
import { resolveDispute } from "../actions";
import { RecordActions } from "@/components/RecordActions";
import { isOwner } from "@/lib/admin";

export default async function BookingDetail({ params, searchParams }: {
  params: Promise<{ id: string }>; searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const { id } = await params;
  const sp = await searchParams;
  const { t, label, dateTime: fmtDateTime, sar: fmtSAR } = await i18n();
  const supabase = await supabaseServer();
  const { data: b } = await supabase.from("bookings").select("*, providers(business_name)").eq("id", id).maybeSingle();
  if (!b) notFound();
  const owner = await isOwner();
  const [events, receipts, disputes, bride] = await Promise.all([
    supabase.from("booking_events").select("from_status, to_status, actor_role, note, created_at").eq("booking_id", id).order("created_at"),
    supabase.from("payment_receipts").select("*").eq("booking_id", id).order("created_at", { ascending: false }),
    supabase.from("disputes").select("*").eq("booking_id", id).order("created_at", { ascending: false }),
    b.bride_id ? supabase.from("profiles").select("phone, display_name").eq("id", b.bride_id).maybeSingle() : Promise.resolve({ data: null }),
  ]);
  // Receipts are private: short-lived signed links, readable only because the admin policy allows it.
  const receiptUrls = await Promise.all((receipts.data ?? []).map(async (r) => {
    if (!r.storage_path) return null;
    const { data } = await supabase.storage.from("receipts").createSignedUrl(r.storage_path, 600);
    return data?.signedUrl ?? null;
  }));
  const open = (disputes.data ?? []).find((d) => d.status === "open");
  const provider = (b as { providers?: { business_name?: string } }).providers;

  return (
    <>
      <div className="topbar">
        <div>
          <h1 className="mono" style={{ fontSize: 22 }}>{b.reference_code}</h1>
          <Badge map={bookingStatus} value={b.status} /> {b.is_demo && <span className="badge">{t("تجريبي", "Demo")}</span>}
        </div>
        <div style={{ display: "grid", gap: 6, justifyItems: "end" }}>
          <Link className="button secondary" href="/bookings">{t("رجوع", "Back")}</Link>
          <RecordActions entity="booking" id={b.id} archived={!!b.archived_at} back={`/bookings/${b.id}`} isOwner={owner} />
        </div>
      </div>
      <Flash sp={sp} />

      <div className="grid two">
        <div className="card">
          <dl className="kv">
            <dt>{t("الخدمة", "Service")}</dt><dd>{b.service_title}</dd>
            <dt>{t("مقدّمة الخدمة", "Provider")}</dt><dd><Link href={`/providers/${b.provider_id}`}>{provider?.business_name ?? "—"}</Link></dd>
            <dt>{t("العروس", "Bride")}</dt><dd>{bride.data?.display_name ?? b.bride_name ?? "—"} <span className="ltr muted">{bride.data?.phone ?? ""}</span></dd>
            <dt>{t("الموعد", "Appointment")}</dt><dd>{fmtDateTime(b.starts_at)}</dd>
            <dt>{t("المبلغ", "Amount")}</dt><dd>{fmtSAR(b.price)}</dd>
            <dt>{t("موعد الدفع", "Payment due")}</dt><dd>{fmtDateTime(b.payment_due_at)}</dd>
            <dt>{t("ملاحظة العروس", "Bride's note")}</dt><dd>{b.note ?? "—"}</dd>
            <dt>{t("طرق الدفع وقت الموافقة", "Payment methods at approval")}</dt>
            <dd>{(b.payment_methods ?? []).map((m: { label: string; value: string }, i: number) => (
              <div key={i} className="small">{m.label} · <span className="ltr mono">{m.value}</span></div>
            ))}</dd>
          </dl>
        </div>
        <div className="card">
          <h2 style={{ marginTop: 0 }}>{t("السجل", "History")}</h2>
          {(events.data ?? []).map((e, i) => (
            <div key={i} className="small" style={{ marginBottom: 6 }}>
              <b>{label(bookingStatus, e.to_status)}</b> · {label(party, e.actor_role)} · {fmtDateTime(e.created_at)}
              {e.note && <div className="muted">{e.note}</div>}
            </div>
          ))}
        </div>
      </div>

      <h2>{t("الإيصالات", "Receipts")}</h2>
      {(receipts.data ?? []).length === 0 ? <p className="muted">{t("لا توجد إيصالات.", "No receipts.")}</p> : (
        <div className="grid two">
          {(receipts.data ?? []).map((r, i) => (
            <div key={r.id} className="card">
              {receiptUrls[i] && <a href={receiptUrls[i]!} target="_blank" rel="noreferrer"><img src={receiptUrls[i]!} alt={t("إيصال", "Receipt")} style={{ maxWidth: "100%", maxHeight: 320, borderRadius: 10 }} /></a>}
              <dl className="kv" style={{ marginTop: 8 }}>
                <dt>{t("المبلغ", "Amount")}</dt><dd>{fmtSAR(r.amount)}</dd>
                <dt>{t("وقت التحويل", "Transferred at")}</dt><dd>{fmtDateTime(r.transferred_at)}</dd>
                <dt>{t("البنك", "Bank")}</dt><dd>{r.sender_bank ?? "—"}</dd>
                <dt>{t("الحالة", "Status")}</dt><dd>{r.status} {r.is_duplicate && <span className="badge bad">{t("مكرر في حجز آخر", "Reused in another booking")}</span>}</dd>
                {r.reject_reason && (<><dt>{t("سبب الرفض", "Rejection reason")}</dt><dd>{r.reject_reason}</dd></>)}
              </dl>
            </div>
          ))}
        </div>
      )}

      <h2>{t("النزاعات", "Disputes")}</h2>
      {(disputes.data ?? []).length === 0 ? <p className="muted">{t("لا توجد نزاعات.", "No disputes.")}</p> : (disputes.data ?? []).map((d) => (
        <div key={d.id} className="card" style={{ marginBottom: 10 }}>
          <b>{label(disputeReason, d.reason)}</b> · {t("فتحتها:", "Opened by:")} {label(party, d.opened_by_role)} · {fmtDateTime(d.created_at)}
          {d.details && <p>{d.details}</p>}
          {d.status !== "open" && <p className="muted">{d.status}: {d.resolution}</p>}
        </div>
      ))}
      {open && (
        <div className="card">
          <h2 style={{ marginTop: 0 }}>{t("إغلاق النزاع", "Close the dispute")}</h2>
          <form className="stack" action={resolveDispute}>
            <input type="hidden" name="booking" value={id} />
            <input type="hidden" name="dispute" value={open.id} />
            <label>{t("القرار", "Decision")}
              <select name="outcome" defaultValue="reject">
                <option value="reject">{t("رفض البلاغ وإعادة الحجز لحالته السابقة", "Reject the claim and restore the booking's previous status")}</option>
                <option value="restore">{t("قبول البلاغ مع إعادة الحجز لحالته السابقة", "Accept the claim and restore the booking's previous status")}</option>
                <option value="completed">{t("اعتبار الحجز مكتملاً", "Mark the booking completed")}</option>
                <option value="cancelled_by_provider">{t("إلغاء على مقدّمة الخدمة", "Cancel, provider at fault")}</option>
                <option value="cancelled_by_bride">{t("إلغاء على العروس", "Cancel, bride at fault")}</option>
              </select>
            </label>
            <label>{t("الملاحظة (تُرسل للطرفين)", "Note (sent to both parties)")}<textarea name="note" required /></label>
            <ConfirmButton message={t("إغلاق النزاع وإشعار الطرفين؟", "Close the dispute and notify both parties?")}>{t("إغلاق النزاع", "Close dispute")}</ConfirmButton>
          </form>
        </div>
      )}
    </>
  );
}
