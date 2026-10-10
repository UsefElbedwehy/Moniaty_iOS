import Link from "next/link";
import { supabaseServer } from "@/lib/supabase/server";
import { Chips, Empty, Flash } from "@/components/ui";
import { ConfirmButton } from "@/components/ConfirmButton";
import { fmtDateTime, param } from "@/lib/format";
import { moderateReview, setBan } from "./actions";

type Review = {
  id: string; booking_id: string; direction: string; author_id: string | null; author_name: string | null;
  provider_id: string; provider_name: string | null; rating: number; body: string | null; photo_urls: string[];
  flagged_words: string[] | null; status: string; created_at: string; moderation_note: string | null;
};

export default async function Reviews({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const sp = await searchParams;
  const status = param(sp.status, "pending");
  const supabase = await supabaseServer();
  // Full author names: this RPC is for moderators only (the app only ever gets masked names).
  const { data, error } = await supabase.rpc("admin_get_reviews", { p_status: status, p_limit: 100, p_offset: 0 });
  const rows = (data ?? []) as Review[];

  return (
    <>
      <div className="topbar"><h1>التقييمات</h1></div>
      <Flash sp={sp} />
      <Chips base="/reviews" current={status} options={[["pending", "بانتظار المراجعة"], ["approved", "منشورة"], ["rejected", "مرفوضة"], ["hidden", "مخفية"]]} />
      {error && <div className="flash err">{error.message}</div>}
      {rows.length === 0 ? <div className="card"><Empty text="لا توجد تقييمات هنا." /></div> : rows.map((r) => (
        <div key={r.id} className="card" style={{ marginBottom: 10 }}>
          <div style={{ display: "flex", justifyContent: "space-between", gap: 12, flexWrap: "wrap" }}>
            <div>
              <b style={{ color: "var(--gold)", fontSize: 18 }}>{"★".repeat(r.rating)}{"☆".repeat(5 - r.rating)}</b>{" "}
              <span className="badge">{r.direction === "bride_to_provider" ? "عروس ← مقدّمة خدمة (عام)" : "مقدّمة خدمة ← عروس (خاص)"}</span>
              <div className="small muted">
                {r.author_name ?? "—"} عن <Link href={`/providers/${r.provider_id}`}>{r.provider_name ?? "—"}</Link> ·{" "}
                <Link href={`/bookings/${r.booking_id}`}>الحجز</Link> · {fmtDateTime(r.created_at)}
              </div>
            </div>
            {r.flagged_words?.length ? <span className="badge bad">كلمات محظورة: {r.flagged_words.join("، ")}</span> : null}
          </div>
          {r.body && <p>{r.body}</p>}
          {r.photo_urls?.length > 0 && (
            <div style={{ display: "flex", gap: 6 }}>{r.photo_urls.map((u) => <a key={u} href={u} target="_blank" rel="noreferrer"><img className="thumb" src={u} alt="" /></a>)}</div>
          )}
          <form className="inline" action={moderateReview} style={{ marginTop: 10 }}>
            <input type="hidden" name="id" value={r.id} />
            <input type="hidden" name="back" value={status} />
            <input name="note" placeholder="ملاحظة (تُرسل للكاتبة عند الرفض)" defaultValue={r.moderation_note ?? ""} style={{ flex: 1 }} />
            {status !== "approved" && <button name="status" value="approved">نشر</button>}
            {status !== "rejected" && <button className="secondary" name="status" value="rejected">رفض</button>}
            {status === "approved" && <button className="secondary" name="status" value="hidden">إخفاء</button>}
          </form>
          {r.author_id && (
            <form className="inline" action={setBan} style={{ marginTop: 6 }}>
              <input type="hidden" name="user" value={r.author_id} />
              <input type="hidden" name="banned" value="true" />
              <input type="hidden" name="back_path" value={`/reviews?status=${status}`} />
              <ConfirmButton message="منع هذا الحساب من كتابة التقييمات؟" className="ghost">منع الكاتبة من التقييم</ConfirmButton>
            </form>
          )}
        </div>
      ))}
    </>
  );
}
