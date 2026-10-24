import Link from "next/link";
import { supabaseServer } from "@/lib/supabase/server";
import { can, type Admin } from "@/lib/admin";
import { i18n } from "@/lib/i18n";
import { thumbUrl } from "@/lib/format";
import { disputeReason, reportReason } from "@/lib/labels";
import { getQueues, totalQueue } from "@/lib/queues";
import { ProviderDecision } from "@/components/ProviderDecision";
import { moderateReview } from "@/app/(admin)/reviews/actions";
import { resolveReport } from "@/app/(admin)/reports/actions";
import { replyTicket } from "@/app/(admin)/support/actions";

const LIMIT = 8;

type PendingProvider = {
  id: string; business_name: string | null; created_at: string; cr_number: string | null; freelance_doc_number: string | null;
  address: string | null; instagram: string | null;
  profiles: { phone: string | null; display_name: string | null } | null;
  provider_categories: { category_id: string }[]; provider_cities: { city_id: string }[];
  services: { id: string }[];
};
type PendingReview = { id: string; rating: number; body: string | null; photo_urls: string[]; author_name: string | null;
  provider_id: string; provider_name: string | null; flagged_words: string[] | null; created_at: string };
type OpenReport = { id: string; target_type: string; target_id: string; reason: string; details: string | null; created_at: string };
type OpenDispute = { id: string; booking_id: string; reason: string; details: string | null; opened_by_role: string; created_at: string;
  bookings: { reference_code: string; service_title: string | null } | null };
type OpenTicket = { id: string; subject: string; message: string; created_at: string; booking_id: string | null;
  profiles: { display_name: string | null; phone: string | null } | null };

const targetHref = (type: string, id: string) =>
  type === "provider" ? `/providers/${id}` : type === "service" ? `/reports/service/${id}` : type === "store" ? `/reports/store/${id}`
  : type === "booking" ? `/bookings/${id}` : type === "user" ? `/users?q=${id}` : "/reviews?status=approved";

/**
 * "Needs action": everything waiting for an admin, each with its decision buttons right here, so
 * the common work (approve a provider, publish a review, close a report, answer a ticket) needs
 * no extra page. Sections show only to admins allowed to act on them.
 */
export async function Inbox({ admin }: { admin: Admin }) {
  const { t, label, list, dateTime, arrow } = await i18n();
  const supabase = await supabaseServer();
  const q = await getQueues();
  const back = "/";
  const age = (iso: string) => Math.max(0, Math.floor((Date.now() - new Date(iso).getTime()) / 3_600_000));

  const [providers, reviews, reports, disputes, tickets] = await Promise.all([
    can(admin, "providers.review") && q.providers_pending
      ? supabase.from("providers").select("id, business_name, created_at, cr_number, freelance_doc_number, address, instagram, profiles!providers_id_fkey(phone, display_name), provider_categories(category_id), provider_cities(city_id), services(id)")
          .eq("status", "pending").is("archived_at", null).order("created_at").limit(LIMIT)
      : null,
    can(admin, "reviews.moderate") && q.reviews_pending ? supabase.rpc("admin_get_reviews", { p_status: "pending", p_limit: LIMIT, p_offset: 0 }) : null,
    can(admin, "reports.handle") && q.reports_open
      ? supabase.from("reports").select("id, target_type, target_id, reason, details, created_at").eq("status", "open").is("archived_at", null).order("created_at").limit(LIMIT)
      : null,
    q.disputes_open
      ? supabase.from("disputes").select("id, booking_id, reason, details, opened_by_role, created_at, bookings(reference_code, service_title)").eq("status", "open").order("created_at").limit(LIMIT)
      : null,
    can(admin, "reports.handle") && q.tickets_open
      ? supabase.from("support_tickets").select("id, subject, message, created_at, booking_id, profiles(display_name, phone)").eq("status", "open").is("archived_at", null).order("created_at").limit(LIMIT)
      : null,
  ]);
  const pendingProviders = (providers?.data ?? []) as unknown as PendingProvider[];
  const pendingReviews = (reviews?.data ?? []) as PendingReview[];
  const openReports = (reports?.data ?? []) as OpenReport[];
  const openDisputes = (disputes?.data ?? []) as unknown as OpenDispute[];
  const openTickets = (tickets?.data ?? []) as unknown as OpenTicket[];
  const more = (shown: number, total: number, href: string) =>
    total > shown ? <Link href={href} className="small">{t(`عرض الكل (${total})`, `See all (${total})`)} {arrow}</Link> : null;

  if (totalQueue(q) === 0) {
    return <div className="card inbox-clear">✓ {t("لا يوجد ما ينتظرك الآن.", "Nothing is waiting for you right now.")}</div>;
  }

  return (
    <div className="inbox">
      {pendingProviders.length > 0 && (
        <section>
          <h3>{t("طلبات انضمام مقدّمات الخدمة", "Provider applications")} <span className="count-pill">{q.providers_pending}</span></h3>
          {pendingProviders.map((p) => (
            <div key={p.id} className="card inbox-card">
              <div className="inbox-head">
                <Link href={`/providers/${p.id}`}><b>{p.business_name || p.profiles?.display_name || t("بدون اسم", "Unnamed")}</b></Link>
                <span className="muted small">{t("منذ", "")} {age(p.created_at)} {t("ساعة", "h ago")}</span>
              </div>
              <div className="small muted">
                <span className="ltr">{p.profiles?.phone ?? "—"}</span>
                {" · "}{list(p.provider_categories.map((c) => c.category_id)) || t("بلا أقسام", "no categories")}
                {" · "}{list(p.provider_cities.map((c) => c.city_id)) || t("بلا مدن", "no cities")}
                {" · "}{t(`${p.services.length} خدمة`, `${p.services.length} services`)}
              </div>
              <div className="small">
                {p.cr_number ? <span className="badge good">{t("سجل تجاري", "CR")} <span className="mono">{p.cr_number}</span></span> : null}{" "}
                {p.freelance_doc_number ? <span className="badge good">{t("عمل حر", "Freelance")} <span className="mono">{p.freelance_doc_number}</span></span> : null}{" "}
                {!p.cr_number && !p.freelance_doc_number ? <span className="badge warn">{t("بلا وثيقة", "No document")}</span> : null}
              </div>
              <ProviderDecision id={p.id} back={back} />
            </div>
          ))}
          {more(pendingProviders.length, q.providers_pending, "/providers?status=pending")}
        </section>
      )}

      {pendingReviews.length > 0 && (
        <section>
          <h3>{t("تقييمات بانتظار النشر", "Reviews to publish")} <span className="count-pill">{q.reviews_pending}</span></h3>
          {pendingReviews.map((r) => (
            <div key={r.id} className="card inbox-card">
              <div className="inbox-head">
                <b style={{ color: "var(--gold)" }}>{"★".repeat(r.rating)}{"☆".repeat(5 - r.rating)}</b>
                <span className="muted small">{r.author_name ?? "—"} {arrow} <Link href={`/providers/${r.provider_id}`}>{r.provider_name ?? "—"}</Link></span>
              </div>
              {r.body && <p style={{ margin: 0 }}>{r.body}</p>}
              {r.photo_urls?.length > 0 && <div style={{ display: "flex", gap: 6 }}>{r.photo_urls.map((u) => <img key={u} className="thumb" src={thumbUrl(u)} alt="" />)}</div>}
              {r.flagged_words?.length ? <span className="badge bad">{t("كلمات محظورة:", "Banned words:")} {list(r.flagged_words)}</span> : null}
              <form className="inline decision" action={moderateReview}>
                <input type="hidden" name="id" value={r.id} />
                <input type="hidden" name="back_path" value={back} />
                <button name="status" value="approved">{t("نشر", "Publish")}</button>
                <input name="note" placeholder={t("سبب الرفض (يُرسل للكاتبة)", "Reason if rejecting (sent to the author)")} />
                <button className="danger" name="status" value="rejected">{t("رفض", "Reject")}</button>
              </form>
            </div>
          ))}
          {more(pendingReviews.length, q.reviews_pending, "/reviews")}
        </section>
      )}

      {openReports.length > 0 && (
        <section>
          <h3>{t("بلاغات مفتوحة", "Open reports")} <span className="count-pill">{q.reports_open}</span></h3>
          {openReports.map((r) => (
            <div key={r.id} className="card inbox-card">
              <div className="inbox-head">
                <span><b>{label(reportReason, r.reason)}</b> · <Link href={targetHref(r.target_type, r.target_id)}>{t("فتح المحتوى", "Open the content")}</Link></span>
                <span className={`badge ${age(r.created_at) >= 20 ? "bad" : ""}`}>{age(r.created_at)} {t("ساعة", "h")}</span>
              </div>
              {r.details && <p style={{ margin: 0 }}>{r.details}</p>}
              <form className="inline decision" action={resolveReport}>
                <input type="hidden" name="id" value={r.id} />
                <input type="hidden" name="back_path" value={back} />
                <input name="note" placeholder={t("ما الإجراء المتخذ؟", "What action was taken?")} />
                <button name="status" value="actioned">{t("تم الإجراء", "Actioned")}</button>
                <button className="secondary" name="status" value="dismissed">{t("رفض البلاغ", "Dismiss")}</button>
              </form>
            </div>
          ))}
          {more(openReports.length, q.reports_open, "/reports")}
        </section>
      )}

      {openDisputes.length > 0 && (
        <section>
          <h3>{t("نزاعات مفتوحة", "Open disputes")} <span className="count-pill">{q.disputes_open}</span></h3>
          {openDisputes.map((d) => (
            <div key={d.id} className="card inbox-card">
              <div className="inbox-head">
                <span><b className="mono">{d.bookings?.reference_code ?? "—"}</b> · {d.bookings?.service_title ?? ""}</span>
                <span className="muted small">{dateTime(d.created_at)}</span>
              </div>
              <div>{label(disputeReason, d.reason)} · <span className="muted">{d.opened_by_role === "bride" ? t("فتحته العروس", "opened by the bride") : t("فتحته مقدّمة الخدمة", "opened by the provider")}</span></div>
              {d.details && <p style={{ margin: 0 }}>{d.details}</p>}
              <Link className="button" href={`/bookings/${d.booking_id}`} style={{ justifySelf: "start" }}>{t("مراجعة وحسم النزاع", "Review and resolve")}</Link>
            </div>
          ))}
          {more(openDisputes.length, q.disputes_open, "/disputes")}
        </section>
      )}

      {openTickets.length > 0 && (
        <section>
          <h3>{t("طلبات دعم", "Support tickets")} <span className="count-pill">{q.tickets_open}</span></h3>
          {openTickets.map((tk) => (
            <div key={tk.id} className="card inbox-card">
              <div className="inbox-head">
                <b>{tk.subject}</b>
                <span className="muted small">{tk.profiles?.display_name ?? "—"} · <span className="ltr">{tk.profiles?.phone ?? ""}</span></span>
              </div>
              <p style={{ margin: 0, whiteSpace: "pre-wrap" }}>{tk.message}</p>
              <form className="stack" action={replyTicket}>
                <input type="hidden" name="id" value={tk.id} />
                <input type="hidden" name="back_path" value={back} />
                <textarea name="reply" required placeholder={t("الرد (يصل كإشعار)", "Reply (sent as a notification)")} />
                <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
                  <label className="check"><input type="checkbox" name="close" defaultChecked /> {t("إغلاق الطلب", "Close ticket")}</label>
                  <button>{t("إرسال الرد", "Send reply")}</button>
                </div>
              </form>
            </div>
          ))}
          {more(openTickets.length, q.tickets_open, "/support")}
        </section>
      )}

      {can(admin, "subscriptions.manage") && q.payments_review > 0 && (
        <section>
          <h3>{t("دفعات اشتراك تحتاج مراجعة", "Plan payments to review")} <span className="count-pill">{q.payments_review}</span></h3>
          <Link className="button secondary" href="/subscriptions?status=review">{t("فتح الدفعات", "Open payments")} {arrow}</Link>
        </section>
      )}
    </div>
  );
}
