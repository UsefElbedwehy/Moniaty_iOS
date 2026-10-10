import Link from "next/link";
import { supabaseServer } from "@/lib/supabase/server";
import { Badge, Chips, Empty, Pager } from "@/components/ui";
import { fmtDateTime, fmtSAR, param, pageRange, PAGE_SIZE } from "@/lib/format";
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
  const supabase = await supabaseServer();
  const select = "id, reference_code, status, price, starts_at, created_at, service_title, bride_name, is_demo, providers(business_name)"
    + (duplicate ? ", payment_receipts!inner(is_duplicate)" : "");
  let query = supabase.from("bookings").select(select).order("created_at", { ascending: false }).range(...pageRange(page));
  if (status) query = query.eq("status", status);
  if (q) query = query.ilike("reference_code", `%${q}%`);
  if (duplicate) query = query.eq("payment_receipts.is_duplicate", true);
  const { data, error } = await query;
  const rows = (data ?? []) as unknown as Row[];

  return (
    <>
      <div className="topbar">
        <h1>الحجوزات</h1>
        <form className="inline" action="/bookings">
          <input name="q" placeholder="رقم الحجز MN-…" defaultValue={q} dir="ltr" />
          <button className="secondary">بحث</button>
        </form>
      </div>
      <Chips base="/bookings" current={duplicate ? "dup" : status} options={[
        ["", "الكل"], ["requested", "بانتظار الموافقة"], ["awaiting_payment", "بانتظار الدفع"], ["payment_submitted", "إيصال مرفوع"],
        ["payment_confirmed", "مؤكدة"], ["completed", "مكتملة"], ["disputed", "نزاع"], ["expired", "منتهية"],
      ]} />
      {duplicate && <p className="muted">حجوزات فيها إيصال استُخدم في حجز آخر.</p>}
      {error && <div className="flash err">{error.message}</div>}
      <div className="table-wrap">
        {rows.length === 0 ? <Empty /> : (
          <table>
            <thead><tr><th>الرقم</th><th>الخدمة</th><th>مقدّمة الخدمة</th><th>العروس</th><th>الموعد</th><th>المبلغ</th><th>الحالة</th></tr></thead>
            <tbody>
              {rows.map((b) => (
                <tr key={b.id}>
                  <td><Link className="mono" href={`/bookings/${b.id}`}>{b.reference_code}</Link>{b.is_demo && <span className="badge"> تجريبي</span>}</td>
                  <td>{b.service_title}</td>
                  <td>{b.providers?.business_name ?? "—"}</td>
                  <td>{b.bride_name ?? "—"}</td>
                  <td>{fmtDateTime(b.starts_at)}</td>
                  <td>{fmtSAR(b.price)}</td>
                  <td><Badge map={bookingStatus} value={b.status} /></td>
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
