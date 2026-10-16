import Link from "next/link";
import { supabaseServer } from "@/lib/supabase/server";
import { Chips, Empty } from "@/components/ui";
import { param } from "@/lib/format";
import { i18n } from "@/lib/i18n";
import { disputeReason, party } from "@/lib/labels";

type Row = { id: string; booking_id: string; reason: string; details: string | null; opened_by_role: string; status: string;
  created_at: string; resolution: string | null; bookings: { reference_code: string } | null };

export default async function Disputes({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const sp = await searchParams;
  const status = param(sp.status, "open");
  const { t, label, dateTime: fmtDateTime } = await i18n();
  const supabase = await supabaseServer();
  const { data } = await supabase.from("disputes").select("*, bookings(reference_code)").eq("status", status)
    .order("created_at", { ascending: status === "open" }).limit(100);
  const rows = (data ?? []) as unknown as Row[];
  return (
    <>
      <div className="topbar"><h1>{t("النزاعات", "Disputes")}</h1></div>
      <Chips base="/disputes" current={status} options={[["open", t("مفتوحة", "Open")], ["resolved", t("مقبولة", "Upheld")], ["rejected", t("مرفوضة", "Rejected")]]} />
      <div className="table-wrap">
        {rows.length === 0 ? <Empty text={t("لا توجد نزاعات.", "No disputes.")} /> : (
          <table>
            <thead><tr><th>{t("الحجز", "Booking")}</th><th>{t("السبب", "Reason")}</th><th>{t("فتحتها", "Opened by")}</th><th>{t("التفاصيل", "Details")}</th><th>{t("التاريخ", "Date")}</th></tr></thead>
            <tbody>{rows.map((d) => (
              <tr key={d.id}>
                <td><Link className="mono" href={`/bookings/${d.booking_id}`}>{d.bookings?.reference_code}</Link></td>
                <td>{label(disputeReason, d.reason)}</td>
                <td>{label(party, d.opened_by_role)}</td>
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
