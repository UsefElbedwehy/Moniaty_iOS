import { supabaseServer } from "@/lib/supabase/server";
import { Stat } from "@/components/ui";
import { fmtNum, fmtSAR } from "@/lib/format";
import { bookingStatus } from "@/lib/labels";

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
  const supabase = await supabaseServer();
  const { data, error } = await supabase.rpc("admin_stats");
  if (error || !data) return <div className="flash err">تعذّر تحميل الأرقام: {error?.message}</div>;
  const s = data as Stats;
  const q = s.queues;
  const bookingsTotal = Object.values(s.bookings_30d).reduce((a, b) => a + b, 0);
  const subs = Object.entries(s.subscriptions_active);

  return (
    <>
      <div className="topbar"><h1>الرئيسية</h1></div>

      <h2>تحتاج إجراء</h2>
      <div className="grid stats">
        <Stat label="طلبات انضمام" value={fmtNum(q.providers_pending)} alert={q.providers_pending > 0} href="/providers?status=pending" />
        <Stat label="نزاعات مفتوحة" value={fmtNum(q.disputes_open)} alert={q.disputes_open > 0} href="/disputes" />
        <Stat label="تقييمات للمراجعة" value={fmtNum(q.reviews_pending)} alert={q.reviews_pending > 0} href="/reviews" />
        <Stat label="بلاغات (خلال ٢٤ ساعة)" value={fmtNum(q.reports_open)} alert={q.reports_open > 0} href="/reports" />
        <Stat label="طلبات دعم" value={fmtNum(q.tickets_open)} alert={q.tickets_open > 0} href="/support" />
        <Stat label="دفعات للمراجعة" value={fmtNum(q.payments_review)} alert={q.payments_review > 0} href="/subscriptions?status=review" />
        <Stat label="إيصالات مكررة" value={fmtNum(q.receipts_duplicate)} alert={q.receipts_duplicate > 0} href="/bookings?duplicate=1" />
      </div>

      <h2>المنصة</h2>
      <div className="grid stats">
        <Stat label="العرائس" value={fmtNum(s.brides)} />
        <Stat label="مقدّمات خدمة ظاهرات" value={fmtNum(s.providers_listed)} />
        <Stat label="في الفترة المجانية" value={fmtNum(s.on_trial)} />
        <Stat label="خدمات ظاهرة" value={fmtNum(s.services_active)} />
        <Stat label="حجوزات (٣٠ يوم)" value={fmtNum(bookingsTotal)} />
        <Stat label="قيمة الحجوزات المؤكدة (٣٠ يوم)" value={fmtSAR(s.bookings_value_30d)} />
        <Stat label="إيراد الاشتراكات (٣٠ يوم)" value={fmtSAR(s.revenue_30d)} />
      </div>

      <div className="grid two" style={{ marginTop: 16 }}>
        <div className="card">
          <h2 style={{ marginTop: 0 }}>الحجوزات حسب الحالة (٣٠ يوم)</h2>
          {Object.entries(s.bookings_30d).length === 0 ? <p className="muted">لا توجد حجوزات بعد.</p> :
            Object.entries(s.bookings_30d).sort((a, b) => b[1] - a[1]).map(([k, n]) => (
              <div key={k} style={{ marginBottom: 8 }}>
                <div style={{ display: "flex", justifyContent: "space-between" }}>
                  <span>{bookingStatus[k]?.[0] ?? k}</span><b>{fmtNum(n)}</b>
                </div>
                <div className="bar"><i style={{ width: `${(n / Math.max(bookingsTotal, 1)) * 100}%` }} /></div>
              </div>
            ))}
        </div>
        <div className="card">
          <h2 style={{ marginTop: 0 }}>الاشتراكات الفعّالة</h2>
          {subs.length === 0 ? <p className="muted">لا توجد اشتراكات مدفوعة بعد.</p> :
            subs.map(([plan, n]) => (
              <div key={plan} style={{ display: "flex", justifyContent: "space-between", marginBottom: 6 }}>
                <span>{plan}</span><b>{fmtNum(n)}</b>
              </div>
            ))}
          <h2>مقدّمات الخدمة</h2>
          {Object.entries(s.providers ?? {}).map(([k, n]) => (
            <div key={k} style={{ display: "flex", justifyContent: "space-between", marginBottom: 6 }}>
              <span>{k}</span><b>{fmtNum(n)}</b>
            </div>
          ))}
        </div>
      </div>
    </>
  );
}
