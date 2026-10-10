import Link from "next/link";
import { supabaseServer } from "@/lib/supabase/server";
import { Chips, Empty } from "@/components/ui";
import { fmtDateTime, param } from "@/lib/format";
import { disputeReason } from "@/lib/labels";

type Row = { id: string; booking_id: string; reason: string; details: string | null; opened_by_role: string; status: string;
  created_at: string; resolution: string | null; bookings: { reference_code: string } | null };

export default async function Disputes({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const sp = await searchParams;
  const status = param(sp.status, "open");
  const supabase = await supabaseServer();
  const { data } = await supabase.from("disputes").select("*, bookings(reference_code)").eq("status", status)
    .order("created_at", { ascending: status === "open" }).limit(100);
  const rows = (data ?? []) as unknown as Row[];
  return (
    <>
      <div className="topbar"><h1>النزاعات</h1></div>
      <Chips base="/disputes" current={status} options={[["open", "مفتوحة"], ["resolved", "مقبولة"], ["rejected", "مرفوضة"]]} />
      <div className="table-wrap">
        {rows.length === 0 ? <Empty text="لا توجد نزاعات." /> : (
          <table>
            <thead><tr><th>الحجز</th><th>السبب</th><th>فتحتها</th><th>التفاصيل</th><th>التاريخ</th></tr></thead>
            <tbody>{rows.map((d) => (
              <tr key={d.id}>
                <td><Link className="mono" href={`/bookings/${d.booking_id}`}>{d.bookings?.reference_code}</Link></td>
                <td>{disputeReason[d.reason] ?? d.reason}</td>
                <td>{d.opened_by_role === "bride" ? "العروس" : "مقدّمة الخدمة"}</td>
                <td>{d.details ?? d.resolution ?? "—"}</td>
                <td>{fmtDateTime(d.created_at)}</td>
              </tr>
            ))}</tbody>
          </table>
        )}
      </div>
    </>
  );
}
