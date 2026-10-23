import Link from "next/link";
import { RecordActions } from "@/components/RecordActions";
import { isOwner } from "@/lib/admin";
import { supabaseServer } from "@/lib/supabase/server";
import { Badge, Chips, Empty, Pager } from "@/components/ui";
import { param, pageRange, PAGE_SIZE } from "@/lib/format";
import { i18n } from "@/lib/i18n";
import { bookingStatus } from "@/lib/labels";

type Row = {
  id: string; reference_code: string; status: string; price: number; starts_at: string; created_at: string;
  service_title: string; bride_name: string | null; is_demo: boolean; providers: { business_name: string | null } | null;
};

export default async function Bookings({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const sp = await searchParams;
  const status = param(sp.status);
  const q = param(sp.q).toUpperCase();
  const duplicate = param(sp.duplicate) === "1";
  const page = Math.max(1, Number(param(sp.page, "1")) || 1);
  const { t, dateTime: fmtDateTime, sar: fmtSAR } = await i18n();
  const supabase = await supabaseServer();
  const select = "id, reference_code, status, price, starts_at, created_at, service_title, bride_name, is_demo, providers(business_name)"
    + (duplicate ? ", payment_receipts!inner(is_duplicate)" : "");
  let query = supabase.from("bookings").select(select).is("archived_at", null).order("created_at", { ascending: false }).range(...pageRange(page));
  if (status) query = query.eq("status", status);
  if (q) query = query.ilike("reference_code", `%${q}%`);
  if (duplicate) query = query.eq("payment_receipts.is_duplicate", true);
  const { data, error } = await query;
  const rows = (data ?? []) as unknown as Row[];

  const owner = await isOwner();
  return (
    <>
      <div className="topbar">
        <h1>{t("الحجوزات", "Bookings")}</h1>
        <form className="inline" action="/bookings">
          <input name="q" placeholder={t("رقم الحجز MN-…", "Booking code MN-…")} defaultValue={q} dir="ltr" />
          <button className="secondary">{t("بحث", "Search")}</button>
        </form>
      </div>
      <Chips base="/bookings" current={duplicate ? "dup" : status} options={[
        ["", t("الكل", "All")], ["requested", t("بانتظار الموافقة", "Awaiting approval")], ["awaiting_payment", t("بانتظار الدفع", "Awaiting payment")], ["payment_submitted", t("إيصال مرفوع", "Receipt uploaded")],
        ["payment_confirmed", t("مؤكدة", "Confirmed")], ["completed", t("مكتملة", "Completed")], ["disputed", t("نزاع", "Disputed")], ["expired", t("منتهية", "Expired")],
      ]} />
      {duplicate && <p className="muted">{t("حجوزات فيها إيصال استُخدم في حجز آخر.", "Bookings with a receipt that was used in another booking.")}</p>}
      {error && <div className="flash err">{error.message}</div>}
      <div className="table-wrap">
        {rows.length === 0 ? <Empty /> : (
          <table>
            <thead><tr><th>{t("الرقم", "Code")}</th><th>{t("الخدمة", "Service")}</th><th>{t("مقدّمة الخدمة", "Provider")}</th><th>{t("العروس", "Bride")}</th><th>{t("الموعد", "Appointment")}</th><th>{t("المبلغ", "Amount")}</th><th>{t("الحالة", "Status")}</th><th></th></tr></thead>
            <tbody>
              {rows.map((b) => (
                <tr key={b.id}>
                  <td><Link className="mono" href={`/bookings/${b.id}`}>{b.reference_code}</Link>{b.is_demo && <span className="badge"> {t("تجريبي", "Demo")}</span>}</td>
                  <td>{b.service_title}</td>
                  <td>{b.providers?.business_name ?? "—"}</td>
                  <td>{b.bride_name ?? "—"}</td>
                  <td>{fmtDateTime(b.starts_at)}</td>
                  <td>{fmtSAR(b.price)}</td>
                  <td><Badge map={bookingStatus} value={b.status} /></td>
                  <td><RecordActions entity="booking" id={b.id} back="/bookings" isOwner={owner} /></td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
      <Pager base="/bookings" page={page} hasMore={rows.length === PAGE_SIZE} query={{ status, q }} />
    </>
  );
}
