import Link from "next/link";
import { countBy, notArchived } from "@/lib/counts";
import { RecordActions } from "@/components/RecordActions";
import { isOwner } from "@/lib/admin";
import { supabaseServer } from "@/lib/supabase/server";
import { Badge, Chips, Empty, Flash } from "@/components/ui";
import { param } from "@/lib/format";
import { i18n } from "@/lib/i18n";
import { ticketStatus } from "@/lib/labels";
import { replyTicket } from "./actions";

type Ticket = { id: string; user_id: string | null; booking_id: string | null; subject: string; message: string; status: string;
  admin_reply: string | null; created_at: string; profiles: { display_name: string | null; phone: string | null; role: string } | null };

export default async function Support({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const sp = await searchParams;
  const status = param(sp.status, "open");
  const { t, dateTime: fmtDateTime } = await i18n();
  const supabase = await supabaseServer();
  const { data } = await supabase.from("support_tickets").select("*, profiles(display_name, phone, role)").eq("status", status).is("archived_at", null)
    .order("created_at", { ascending: status === "open" }).limit(100);
  const rows = (data ?? []) as unknown as Ticket[];
  const owner = await isOwner();
  const counts = await countBy("support_tickets", "status", ["open", "answered", "closed"], notArchived);
  return (
    <>
      <div className="topbar"><h1>{t("طلبات الدعم", "Support tickets")}</h1></div>
      <Flash sp={sp} />
      <Chips base="/support" current={status} options={[["open", t("مفتوحة", "Open")], ["answered", t("تم الرد", "Answered")], ["closed", t("مغلقة", "Closed")]]}  counts={counts} />
      {rows.length === 0 ? <div className="card"><Empty text={t("لا توجد طلبات.", "No tickets.")} /></div> : rows.map((tk) => (
        <div key={tk.id} className="card" style={{ marginBottom: 10 }}>
          <div style={{ display: "flex", justifyContent: "space-between", flexWrap: "wrap", gap: 8 }}>
            <b>{tk.subject}</b>
            <span><Badge map={ticketStatus} value={tk.status} /> <span className="muted small">{fmtDateTime(tk.created_at)}</span></span>
          </div>
          <div className="small muted">
            {tk.profiles?.display_name ?? "—"} · <span className="ltr">{tk.profiles?.phone ?? ""}</span>
            {tk.booking_id && <> · <Link href={`/bookings/${tk.booking_id}`}>{t("الحجز", "Booking")}</Link></>}
          </div>
          <p style={{ whiteSpace: "pre-wrap" }}>{tk.message}</p>
          {tk.admin_reply && <p className="flash ok" style={{ whiteSpace: "pre-wrap" }}>{tk.admin_reply}</p>}
          <div style={{ marginBottom: 8 }}><RecordActions entity="ticket" id={tk.id} back={`/support?status=${status}`} isOwner={owner} /></div>
          {tk.status !== "closed" && (
            <form className="stack" action={replyTicket}>
              <input type="hidden" name="id" value={tk.id} />
              <textarea name="reply" required placeholder={t("الرد (يصل للمستخدم كإشعار)", "Reply (sent to the user as a notification)")} />
              <div className="inline" style={{ display: "flex", gap: 8, alignItems: "center" }}>
                <label className="check"><input type="checkbox" name="close" /> {t("إغلاق الطلب", "Close ticket")}</label>
                <button>{t("إرسال الرد", "Send reply")}</button>
              </div>
            </form>
          )}
        </div>
      ))}
    </>
  );
}
