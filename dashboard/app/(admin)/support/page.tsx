import Link from "next/link";
import { supabaseServer } from "@/lib/supabase/server";
import { Badge, Chips, Empty, Flash } from "@/components/ui";
import { fmtDateTime, param } from "@/lib/format";
import { ticketStatus } from "@/lib/labels";
import { replyTicket } from "./actions";

type Ticket = { id: string; user_id: string | null; booking_id: string | null; subject: string; message: string; status: string;
  admin_reply: string | null; created_at: string; profiles: { display_name: string | null; phone: string | null; role: string } | null };

export default async function Support({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const sp = await searchParams;
  const status = param(sp.status, "open");
  const supabase = await supabaseServer();
  const { data } = await supabase.from("support_tickets").select("*, profiles(display_name, phone, role)").eq("status", status)
    .order("created_at", { ascending: status === "open" }).limit(100);
  const rows = (data ?? []) as unknown as Ticket[];
  return (
    <>
      <div className="topbar"><h1>طلبات الدعم</h1></div>
      <Flash sp={sp} />
      <Chips base="/support" current={status} options={[["open", "مفتوحة"], ["answered", "تم الرد"], ["closed", "مغلقة"]]} />
      {rows.length === 0 ? <div className="card"><Empty text="لا توجد طلبات." /></div> : rows.map((t) => (
        <div key={t.id} className="card" style={{ marginBottom: 10 }}>
          <div style={{ display: "flex", justifyContent: "space-between", flexWrap: "wrap", gap: 8 }}>
            <b>{t.subject}</b>
            <span><Badge map={ticketStatus} value={t.status} /> <span className="muted small">{fmtDateTime(t.created_at)}</span></span>
          </div>
          <div className="small muted">
            {t.profiles?.display_name ?? "—"} · <span className="ltr">{t.profiles?.phone ?? ""}</span>
            {t.booking_id && <> · <Link href={`/bookings/${t.booking_id}`}>الحجز</Link></>}
          </div>
          <p style={{ whiteSpace: "pre-wrap" }}>{t.message}</p>
          {t.admin_reply && <p className="flash ok" style={{ whiteSpace: "pre-wrap" }}>{t.admin_reply}</p>}
          {t.status !== "closed" && (
            <form className="stack" action={replyTicket}>
              <input type="hidden" name="id" value={t.id} />
              <textarea name="reply" required placeholder="الرد (يصل للمستخدم كإشعار)" />
              <div className="inline" style={{ display: "flex", gap: 8, alignItems: "center" }}>
                <label className="check"><input type="checkbox" name="close" /> إغلاق الطلب</label>
                <button>إرسال الرد</button>
              </div>
            </form>
          )}
        </div>
      ))}
    </>
  );
}
