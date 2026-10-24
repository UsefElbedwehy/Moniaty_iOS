import { supabaseServer } from "@/lib/supabase/server";
import { Stat } from "@/components/ui";
import { Inbox } from "@/components/Inbox";
import { requireAdmin } from "@/lib/admin";
import { getQueues } from "@/lib/queues";
import { i18n } from "@/lib/i18n";
import { bookingStatus, providerStatus } from "@/lib/labels";

type Stats = {
  brides: number;
  providers: Record<string, number> | null;
  providers_listed: number;
  services_active: number;
  bookings_30d: Record<string, number>;
  bookings_value_30d: number;
  subscriptions_active: Record<string, number>;
  on_trial: number;
  revenue_30d: number;
  queues: Record<string, number>;
};

export default async function Overview() {
  const { t, label, num: fmtNum, sar: fmtSAR } = await i18n();
  const supabase = await supabaseServer();
  const { data, error } = await supabase.rpc("admin_stats");
  if (error || !data) return <div className="flash err">{t("تعذّر تحميل الأرقام:", "Couldn't load the numbers:")} {error?.message}</div>;
  const s = data as Stats;
  const q = await getQueues();
  const admin = await requireAdmin();
  const bookingsTotal = Object.values(s.bookings_30d).reduce((a, b) => a + b, 0);
  const subs = Object.entries(s.subscriptions_active);

  return (
    <>
      <div className="topbar"><h1>{t("تحتاج إجراء", "Needs action")}</h1></div>
      <Inbox admin={admin} />

      <h2>{t("العدّادات", "Queues")}</h2>
      <div className="grid stats">
        <Stat label={t("طلبات انضمام", "Provider applications")} value={fmtNum(q.providers_pending)} alert={q.providers_pending > 0} href="/providers?status=pending" />
        <Stat label={t("نزاعات مفتوحة", "Open disputes")} value={fmtNum(q.disputes_open)} alert={q.disputes_open > 0} href="/disputes" />
        <Stat label={t("تقييمات للمراجعة", "Reviews to moderate")} value={fmtNum(q.reviews_pending)} alert={q.reviews_pending > 0} href="/reviews" />
        <Stat label={t("بلاغات (خلال ٢٤ ساعة)", "Reports (within 24 h)")} value={fmtNum(q.reports_open)} alert={q.reports_open > 0} href="/reports" />
        <Stat label={t("طلبات دعم", "Support tickets")} value={fmtNum(q.tickets_open)} alert={q.tickets_open > 0} href="/support" />
        <Stat label={t("دفعات للمراجعة", "Payments to review")} value={fmtNum(q.payments_review)} alert={q.payments_review > 0} href="/subscriptions?status=review" />
        <Stat label={t("إيصالات مكررة", "Duplicate receipts")} value={fmtNum(q.receipts_duplicate)} alert={q.receipts_duplicate > 0} href="/bookings?duplicate=1" />
      </div>

      <h2>{t("المنصة", "Platform")}</h2>
      <div className="grid stats">
        <Stat label={t("العرائس", "Brides")} value={fmtNum(s.brides)} />
        <Stat label={t("مقدّمات خدمة ظاهرات", "Listed providers")} value={fmtNum(s.providers_listed)} />
        <Stat label={t("في الفترة المجانية", "On free trial")} value={fmtNum(s.on_trial)} />
        <Stat label={t("خدمات ظاهرة", "Listed services")} value={fmtNum(s.services_active)} />
        <Stat label={t("حجوزات (٣٠ يوم)", "Bookings (30 days)")} value={fmtNum(bookingsTotal)} />
        <Stat label={t("قيمة الحجوزات المؤكدة (٣٠ يوم)", "Confirmed booking value (30 days)")} value={fmtSAR(s.bookings_value_30d)} />
        <Stat label={t("إيراد الاشتراكات (٣٠ يوم)", "Subscription revenue (30 days)")} value={fmtSAR(s.revenue_30d)} />
      </div>

      <div className="grid two">
        <div className="card">
          <h2 style={{ marginTop: 0 }}>{t("الحجوزات حسب الحالة (٣٠ يوم)", "Bookings by status (30 days)")}</h2>
          {Object.entries(s.bookings_30d).length === 0 ? <p className="muted">{t("لا توجد حجوزات بعد.", "No bookings yet.")}</p> :
            Object.entries(s.bookings_30d).sort((a, b) => b[1] - a[1]).map(([k, n]) => (
              <div key={k} className="meter">
                <div className="row" style={{ padding: 0 }}>
                  <span>{label(bookingStatus, k)}</span><b>{fmtNum(n)}</b>
                </div>
                <div className="bar"><i style={{ width: `${(n / Math.max(bookingsTotal, 1)) * 100}%` }} /></div>
              </div>
            ))}
        </div>
        <div className="card">
          <h2 style={{ marginTop: 0 }}>{t("الاشتراكات الفعّالة", "Active subscriptions")}</h2>
          {subs.length === 0 ? <p className="muted">{t("لا توجد اشتراكات مدفوعة بعد.", "No paid subscriptions yet.")}</p> :
            subs.map(([plan, n]) => (
              <div key={plan} className="row">
                <span>{plan}</span><b>{fmtNum(n)}</b>
              </div>
            ))}
          <h2>{t("مقدّمات الخدمة", "Providers")}</h2>
          {Object.entries(s.providers ?? {}).map(([k, n]) => (
            <div key={k} className="row">
              <span>{label(providerStatus, k)}</span><b>{fmtNum(n)}</b>
            </div>
          ))}
        </div>
      </div>
    </>
  );
}
