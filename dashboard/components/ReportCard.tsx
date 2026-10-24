import Link from "next/link";
import { Badge } from "@/components/ui";
import { i18n } from "@/lib/i18n";
import { reportReason, reportStatus } from "@/lib/labels";
import { targetOf, type ReportContext, type ReportRow } from "@/lib/reports";
import { resolveReport } from "@/app/(admin)/reports/actions";

/**
 * One report, laid out so each part is labelled: who reported, what she reported (by name, not
 * id), the reason she picked, her own message, and the admin's decision or the form to make it.
 */
export async function ReportCard({ report: r, ctx, back, children }: {
  report: ReportRow; ctx: ReportContext; back: string; children?: React.ReactNode;
}) {
  const { t, label, dateTime } = await i18n();
  const typeName: Record<string, string> = {
    provider: t("مقدّمة خدمة", "a provider"), service: t("خدمة", "a service"), store: t("متجر", "a store"),
    review: t("تقييم", "a review"), booking: t("حجز", "a booking"), user: t("مستخدم", "a user"),
  };
  const roleName = (role: string | null) =>
    role === "provider" ? t("مقدّمة خدمة", "Provider") : role === "bride" ? t("عروس", "Bride") : null;
  const reporter = r.reporter_id ? ctx.reporters.get(r.reporter_id) : undefined;
  const target = targetOf(ctx, r);
  const age = Math.max(0, Math.floor((Date.now() - new Date(r.created_at).getTime()) / 3_600_000));
  const late = r.status === "open" && age >= 20;

  return (
    <div className="card report">
      <div className="report-head">
        <h3>
          {t("بلاغ عن", "Report about")} {typeName[r.target_type] ?? r.target_type}
          {target?.title && r.target_type !== "review" ? <>: <span className="report-name">{target.title}</span></> : null}
        </h3>
        <div className="report-badges">
          <Badge map={reportStatus} value={r.status} />
          <span className={`badge ${late ? "bad" : ""}`} title={dateTime(r.created_at)}>
            {t(`منذ ${age} ساعة`, `${age} h ago`)}
          </span>
        </div>
      </div>

      <dl className="kv report-kv">
        <dt>{t("المُبلِّغ", "Reported by")}</dt>
        <dd>
          {reporter ? (
            <>
              <b>{reporter.name ?? t("بدون اسم", "No name")}</b>
              {roleName(reporter.role) && <> <span className="badge">{roleName(reporter.role)}</span></>}
              {reporter.phone && <> · <Link href={`/users?q=${encodeURIComponent(reporter.phone)}`} className="ltr">{reporter.phone}</Link></>}
              {reporter.deleted && <> <span className="badge">{t("حساب محذوف", "Deleted account")}</span></>}
            </>
          ) : <span className="muted">{t("حساب محذوف أو غير معروف", "Deleted or unknown account")}</span>}
        </dd>

        <dt>{t("المُبلَّغ عنه", "What was reported")}</dt>
        <dd>
          {target ? (
            <div className="report-target">
              {r.target_type === "review" ? (
                <>
                  <div>
                    <span style={{ color: "var(--gold)" }}>{"★".repeat(target.rating ?? 0)}{"☆".repeat(5 - (target.rating ?? 0))}</span>
                    {target.subtitle && <span className="muted"> {t("عن", "about")} {target.subtitle}</span>}
                  </div>
                  <blockquote className="quote">{target.title || t("(تقييم بدون نص)", "(rating with no text)")}</blockquote>
                </>
              ) : (
                <>
                  <div>
                    <b>{target.title ?? "—"}</b>
                    {target.subtitle && (
                      <span className="muted">
                        {" · "}{r.target_type === "service" || r.target_type === "store" ? t("لدى ", "by ") : ""}{target.subtitle}
                      </span>
                    )}
                  </div>
                </>
              )}
              <Link href={target.href} className="small">{t("فتح ←", "Open →")}</Link>
            </div>
          ) : (
            <span className="muted">{t("لم يعد موجوداً", "No longer exists")} <span className="mono">{r.target_id.slice(0, 8)}</span></span>
          )}
        </dd>

        <dt>{t("السبب", "Reason")}</dt>
        <dd><b>{label(reportReason, r.reason)}</b> <span className="muted small">{t("(اختارته المُبلِّغة من القائمة)", "(chosen from the list)")}</span></dd>

        <dt>{t("رسالة المُبلِّغ", "Reporter's message")}</dt>
        <dd>
          {r.details
            ? <blockquote className="quote">{r.details}</blockquote>
            : <span className="muted">{t("لم يكتب تفاصيل", "No message written")}</span>}
        </dd>

        {r.status !== "open" && (
          <>
            <dt>{t("قرار الإدارة", "Admin decision")}</dt>
            <dd>
              <Badge map={reportStatus} value={r.status} /> {r.resolution_note ?? <span className="muted">{t("بدون ملاحظة", "No note")}</span>}
              {r.handled_at && <span className="muted small"> · {dateTime(r.handled_at)}</span>}
            </dd>
          </>
        )}
      </dl>

      {r.status === "open" && (
        <form className="inline report-form" action={resolveReport}>
          <input type="hidden" name="id" value={r.id} />
          <input type="hidden" name="back_path" value={back} />
          <label className="report-note">
            {t("ما الإجراء الذي اتخذتِه؟ (للإدارة فقط؛ المُبلِّغ يصله شكر عام دون هذا النص)", "What did you do? (for admins only; the reporter just gets a general thank-you)")}
            <input name="note" placeholder={t("مثال: أُخفي التقييم / أُوقفت الخدمة", "e.g. hid the review / paused the service")} />
          </label>
          <button name="status" value="actioned">{t("تم الإجراء", "Actioned")}</button>
          <button className="secondary" name="status" value="dismissed">{t("رفض البلاغ", "Dismiss")}</button>
        </form>
      )}
      {children}
    </div>
  );
}
