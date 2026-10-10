import Link from "next/link";
import { notFound } from "next/navigation";
import { supabaseServer } from "@/lib/supabase/server";
import { Badge, Flash } from "@/components/ui";
import { ConfirmButton } from "@/components/ConfirmButton";
import { fmtDateTime, fmtSAR } from "@/lib/format";
import { bookingStatus, disputeReason } from "@/lib/labels";
import { resolveDispute } from "../actions";

export default async function BookingDetail({ params, searchParams }: {
  params: Promise<{ id: string }>; searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const { id } = await params;
  const sp = await searchParams;
  const supabase = await supabaseServer();
  const { data: b } = await supabase.from("bookings").select("*, providers(business_name)").eq("id", id).maybeSingle();
  if (!b) notFound();
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
          <Badge map={bookingStatus} value={b.status} /> {b.is_demo && <span className="badge">تجريبي</span>}
        </div>
        <Link className="button secondary" href="/bookings">رجوع</Link>
      </div>
      <Flash sp={sp} />

      <div className="grid two">
        <div className="card">
          <dl className="kv">
            <dt>الخدمة</dt><dd>{b.service_title}</dd>
            <dt>مقدّمة الخدمة</dt><dd><Link href={`/providers/${b.provider_id}`}>{provider?.business_name ?? "—"}</Link></dd>
            <dt>العروس</dt><dd>{bride.data?.display_name ?? b.bride_name ?? "—"} <span className="ltr muted">{bride.data?.phone ?? ""}</span></dd>
            <dt>الموعد</dt><dd>{fmtDateTime(b.starts_at)}</dd>
            <dt>المبلغ</dt><dd>{fmtSAR(b.price)}</dd>
            <dt>موعد الدفع</dt><dd>{fmtDateTime(b.payment_due_at)}</dd>
            <dt>ملاحظة العروس</dt><dd>{b.note ?? "—"}</dd>
            <dt>طرق الدفع وقت الموافقة</dt>
            <dd>{(b.payment_methods ?? []).map((m: { label: string; value: string }, i: number) => (
              <div key={i} className="small">{m.label} · <span className="ltr mono">{m.value}</span></div>
            ))}</dd>
          </dl>
        </div>
        <div className="card">
          <h2 style={{ marginTop: 0 }}>السجل</h2>
          {(events.data ?? []).map((e, i) => (
            <div key={i} className="small" style={{ marginBottom: 6 }}>
              <b>{bookingStatus[e.to_status]?.[0] ?? e.to_status}</b> · {e.actor_role} · {fmtDateTime(e.created_at)}
              {e.note && <div className="muted">{e.note}</div>}
            </div>
          ))}
        </div>
      </div>

      <h2>الإيصالات</h2>
      {(receipts.data ?? []).length === 0 ? <p className="muted">لا توجد إيصالات.</p> : (
        <div className="grid two">
          {(receipts.data ?? []).map((r, i) => (
            <div key={r.id} className="card">
              {receiptUrls[i] && <a href={receiptUrls[i]!} target="_blank" rel="noreferrer"><img src={receiptUrls[i]!} alt="إيصال" style={{ maxWidth: "100%", maxHeight: 320, borderRadius: 10 }} /></a>}
              <dl className="kv" style={{ marginTop: 8 }}>
                <dt>المبلغ</dt><dd>{fmtSAR(r.amount)}</dd>
                <dt>وقت التحويل</dt><dd>{fmtDateTime(r.transferred_at)}</dd>
                <dt>البنك</dt><dd>{r.sender_bank ?? "—"}</dd>
                <dt>الحالة</dt><dd>{r.status} {r.is_duplicate && <span className="badge bad">مكرر في حجز آخر</span>}</dd>
                {r.reject_reason && (<><dt>سبب الرفض</dt><dd>{r.reject_reason}</dd></>)}
              </dl>
            </div>
          ))}
        </div>
      )}

      <h2>النزاعات</h2>
      {(disputes.data ?? []).length === 0 ? <p className="muted">لا توجد نزاعات.</p> : (disputes.data ?? []).map((d) => (
        <div key={d.id} className="card" style={{ marginBottom: 10 }}>
          <b>{disputeReason[d.reason] ?? d.reason}</b> · فتحتها: {d.opened_by_role === "bride" ? "العروس" : "مقدّمة الخدمة"} · {fmtDateTime(d.created_at)}
          {d.details && <p>{d.details}</p>}
          {d.status !== "open" && <p className="muted">{d.status}: {d.resolution}</p>}
        </div>
      ))}
      {open && (
        <div className="card">
          <h2 style={{ marginTop: 0 }}>إغلاق النزاع</h2>
          <form className="stack" action={resolveDispute}>
            <input type="hidden" name="booking" value={id} />
            <input type="hidden" name="dispute" value={open.id} />
            <label>القرار
              <select name="outcome" defaultValue="reject">
                <option value="reject">رفض البلاغ وإعادة الحجز لحالته السابقة</option>
                <option value="restore">قبول البلاغ مع إعادة الحجز لحالته السابقة</option>
                <option value="completed">اعتبار الحجز مكتملاً</option>
                <option value="cancelled_by_provider">إلغاء على مقدّمة الخدمة</option>
                <option value="cancelled_by_bride">إلغاء على العروس</option>
              </select>
            </label>
            <label>الملاحظة (تُرسل للطرفين)<textarea name="note" required /></label>
            <ConfirmButton message="إغلاق النزاع وإشعار الطرفين؟">إغلاق النزاع</ConfirmButton>
          </form>
        </div>
      )}
    </>
  );
}
