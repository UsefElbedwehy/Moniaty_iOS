import Link from "next/link";
import { supabaseServer } from "@/lib/supabase/server";
import { Chips, Empty, Flash } from "@/components/ui";
import { ConfirmButton } from "@/components/ConfirmButton";
import { param } from "@/lib/format";
import { i18n } from "@/lib/i18n";
import { moderateReview, setBan } from "./actions";

type Review = {
  id: string; booking_id: string; direction: string; author_id: string | null; author_name: string | null;
  provider_id: string; provider_name: string | null; rating: number; body: string | null; photo_urls: string[];
  flagged_words: string[] | null; status: string; created_at: string; moderation_note: string | null;
};

export default async function Reviews({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const sp = await searchParams;
  const status = param(sp.status, "pending");
  const { t, list, arrow, dateTime: fmtDateTime } = await i18n();
  const supabase = await supabaseServer();
  // Full author names: this RPC is for moderators only (the app only ever gets masked names).
  const { data, error } = await supabase.rpc("admin_get_reviews", { p_status: status, p_limit: 100, p_offset: 0 });
  const rows = (data ?? []) as Review[];

  return (
    <>
      <div className="topbar"><h1>{t("التقييمات", "Reviews")}</h1></div>
      <Flash sp={sp} />
      <Chips base="/reviews" current={status} options={[["pending", t("بانتظار المراجعة", "Pending")], ["approved", t("منشورة", "Published")], ["rejected", t("مرفوضة", "Rejected")], ["hidden", t("مخفية", "Hidden")]]} />
      {error && <div className="flash err">{error.message}</div>}
      {rows.length === 0 ? <div className="card"><Empty text={t("لا توجد تقييمات هنا.", "No reviews here.")} /></div> : rows.map((r) => (
        <div key={r.id} className="card" style={{ marginBottom: 10 }}>
          <div style={{ display: "flex", justifyContent: "space-between", gap: 12, flexWrap: "wrap" }}>
            <div>
              <b style={{ color: "var(--gold)", fontSize: 18 }}>{"★".repeat(r.rating)}{"☆".repeat(5 - r.rating)}</b>{" "}
              <span className="badge">{r.direction === "bride_to_provider" ? `${t("عروس", "Bride")} ${arrow} ${t("مقدّمة خدمة (عام)", "provider (public)")}` : `${t("مقدّمة خدمة", "Provider")} ${arrow} ${t("عروس (خاص)", "bride (private)")}`}</span>
              <div className="small muted">
                {r.author_name ?? "—"} {t("عن", "about")} <Link href={`/providers/${r.provider_id}`}>{r.provider_name ?? "—"}</Link> ·{" "}
                <Link href={`/bookings/${r.booking_id}`}>{t("الحجز", "Booking")}</Link> · {fmtDateTime(r.created_at)}
              </div>
            </div>
            {r.flagged_words?.length ? <span className="badge bad">{t("كلمات محظورة:", "Banned words:")} {list(r.flagged_words)}</span> : null}
          </div>
          {r.body && <p>{r.body}</p>}
          {r.photo_urls?.length > 0 && (
            <div style={{ display: "flex", gap: 6 }}>{r.photo_urls.map((u) => <a key={u} href={u} target="_blank" rel="noreferrer"><img className="thumb" src={u} alt="" /></a>)}</div>
          )}
          <form className="inline" action={moderateReview} style={{ marginTop: 10 }}>
            <input type="hidden" name="id" value={r.id} />
            <input type="hidden" name="back" value={status} />
            <input name="note" placeholder={t("ملاحظة (تُرسل للكاتبة عند الرفض)", "Note (sent to the author if rejected)")} defaultValue={r.moderation_note ?? ""} style={{ flex: 1 }} />
            {status !== "approved" && <button name="status" value="approved">{t("نشر", "Publish")}</button>}
            {status !== "rejected" && <button className="secondary" name="status" value="rejected">{t("رفض", "Reject")}</button>}
            {status === "approved" && <button className="secondary" name="status" value="hidden">{t("إخفاء", "Hide")}</button>}
          </form>
          {r.author_id && (
            <form className="inline" action={setBan} style={{ marginTop: 6 }}>
              <input type="hidden" name="user" value={r.author_id} />
              <input type="hidden" name="banned" value="true" />
              <input type="hidden" name="back_path" value={`/reviews?status=${status}`} />
              <ConfirmButton message={t("منع هذا الحساب من كتابة التقييمات؟", "Stop this account from writing reviews?")} className="ghost">{t("منع الكاتبة من التقييم", "Ban author from reviewing")}</ConfirmButton>
            </form>
          )}
        </div>
      ))}
    </>
  );
}
