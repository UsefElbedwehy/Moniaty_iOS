import Link from "next/link";
import { supabaseServer } from "@/lib/supabase/server";
import { Badge, Chips, Empty, Flash } from "@/components/ui";
import { fmtDateTime, param } from "@/lib/format";
import { reportReason, reportStatus } from "@/lib/labels";
import { resolveReport } from "./actions";

type Report = { id: string; reporter_id: string | null; target_type: string; target_id: string; reason: string;
  details: string | null; status: string; resolution_note: string | null; created_at: string };

/** Where to look at the reported thing. */
function targetLink(type: string, id: string): [string, string] {
  switch (type) {
    case "provider": return [`/providers/${id}`, "مقدّمة خدمة"];
    case "booking": return [`/bookings/${id}`, "حجز"];
    case "review": return [`/reviews?status=approved`, "تقييم"];
    case "user": return [`/users?q=${id}`, "مستخدم"];
    case "service": return [`/reports/service/${id}`, "خدمة"];
    case "store": return [`/reports/store/${id}`, "متجر"];
    default: return ["#", type];
  }
}

export default async function Reports({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const sp = await searchParams;
  const status = param(sp.status, "open");
  const supabase = await supabaseServer();
  const { data } = await supabase.from("reports").select("*").eq("status", status)
    .order("created_at", { ascending: status === "open" }).limit(100);
  const rows = (data ?? []) as Report[];
  const hours = (iso: string) => Math.floor((Date.now() - new Date(iso).getTime()) / 3_600_000);

  return (
    <>
      <div className="topbar"><h1>البلاغات</h1><span className="muted">الهدف: الإجراء خلال ٢٤ ساعة (إرشادات Apple)</span></div>
      <Flash sp={sp} />
      <Chips base="/reports" current={status} options={[["open", "مفتوحة"], ["actioned", "تم الإجراء"], ["dismissed", "مرفوضة"]]} />
      {rows.length === 0 ? <div className="card"><Empty text="لا توجد بلاغات." /></div> : rows.map((r) => {
        const [href, label] = targetLink(r.target_type, r.target_id);
        const age = hours(r.created_at);
        return (
          <div key={r.id} className="card" style={{ marginBottom: 10 }}>
            <div style={{ display: "flex", justifyContent: "space-between", flexWrap: "wrap", gap: 8 }}>
              <div>
                <b>{reportReason[r.reason] ?? r.reason}</b> · <Link href={href}>{label}</Link>{" "}
                <span className="mono muted">{r.target_id.slice(0, 8)}</span>
              </div>
              <div>
                <Badge map={reportStatus} value={r.status} />{" "}
                <span className={`badge ${status === "open" && age >= 20 ? "bad" : ""}`}>{fmtDateTime(r.created_at)} · {age} ساعة</span>
              </div>
            </div>
            {r.details && <p>{r.details}</p>}
            {r.status === "open" ? (
              <form className="inline" action={resolveReport}>
                <input type="hidden" name="id" value={r.id} />
                <input name="note" placeholder="ما الإجراء المتخذ؟" style={{ flex: 1 }} />
                <button name="status" value="actioned">تم الإجراء</button>
                <button className="secondary" name="status" value="dismissed">رفض البلاغ</button>
              </form>
            ) : <p className="muted small">{r.resolution_note}</p>}
          </div>
        );
      })}
    </>
  );
}
