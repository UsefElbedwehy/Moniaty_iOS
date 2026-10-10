import { supabaseServer } from "@/lib/supabase/server";
import { Chips } from "@/components/ui";
import { fmtNum, fmtDateTime, param } from "@/lib/format";

type Analytics = {
  daily: { day: string; event: string; n: number }[];
  signups: { day: string; role: string; n: number }[];
  funnel: Record<string, number>;
  top_searches: { query: string; n: number }[];
  top_errors: { code: string; n: number; last: string }[];
  by_city: { city_id: string; n: number }[];
};

const funnelSteps: [string, string][] = [
  ["service_views", "مشاهدات الخدمات"], ["booking_started", "ضغط «احجزي»"], ["requested", "طلبات حجز"],
  ["approved", "تمت الموافقة"], ["paid", "مدفوعة"], ["completed", "مكتملة"],
];

/** A small bar chart per day, no chart library. */
function DailyBars({ points, label }: { points: { day: string; n: number }[]; label: string }) {
  const max = Math.max(1, ...points.map((p) => p.n));
  return (
    <div className="card">
      <h2 style={{ marginTop: 0 }}>{label}</h2>
      {points.length === 0 ? <p className="muted">لا توجد بيانات.</p> : (
        <div style={{ display: "flex", alignItems: "flex-end", gap: 3, height: 120, direction: "ltr" }}>
          {points.map((p) => (
            <div key={p.day} title={`${p.day}: ${p.n}`} style={{ flex: 1, background: "var(--primary)", borderRadius: 3, height: `${(p.n / max) * 100}%`, minHeight: 2 }} />
          ))}
        </div>
      )}
    </div>
  );
}

const sumByDay = (rows: { day: string; n: number }[]) =>
  Object.entries(rows.reduce<Record<string, number>>((a, r) => ({ ...a, [r.day]: (a[r.day] ?? 0) + r.n }), {}))
    .sort(([a], [b]) => a.localeCompare(b)).map(([day, n]) => ({ day, n }));

export default async function AnalyticsPage({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const sp = await searchParams;
  const days = param(sp.days, "30");
  const supabase = await supabaseServer();
  const { data, error } = await supabase.rpc("admin_analytics", { p_days: Number(days) });
  if (error || !data) return <div className="flash err">{error?.message}</div>;
  const a = data as Analytics;
  const top = a.funnel.service_views || 1;
  const eventTotals = Object.entries(a.daily.reduce<Record<string, number>>((acc, r) => ({ ...acc, [r.event]: (acc[r.event] ?? 0) + r.n }), {}))
    .sort((x, y) => y[1] - x[1]);

  return (
    <>
      <div className="topbar"><h1>التحليلات</h1><span className="muted small">تفاصيل الشاشات والضغطات في Firebase Analytics، والأعطال في Crashlytics.</span></div>
      <Chips base="/analytics" name="days" current={days} options={[["7", "٧ أيام"], ["30", "٣٠ يوم"], ["90", "٩٠ يوم"]]} />
      <div className="grid two">
        <DailyBars label="التسجيلات اليومية" points={sumByDay(a.signups)} />
        <DailyBars label="الأحداث اليومية" points={sumByDay(a.daily)} />
      </div>
      <div className="grid two" style={{ marginTop: 12 }}>
        <div className="card">
          <h2 style={{ marginTop: 0 }}>مسار الحجز</h2>
          {funnelSteps.map(([k, label]) => (
            <div key={k} style={{ marginBottom: 8 }}>
              <div style={{ display: "flex", justifyContent: "space-between" }}><span>{label}</span><b>{fmtNum(a.funnel[k])}</b></div>
              <div className="bar"><i style={{ width: `${Math.min(100, ((a.funnel[k] ?? 0) / top) * 100)}%` }} /></div>
            </div>
          ))}
          <p className="muted small">الحجوزات التجريبية مستبعدة.</p>
        </div>
        <div className="card">
          <h2 style={{ marginTop: 0 }}>الأحداث</h2>
          {eventTotals.map(([e, n]) => <div key={e} style={{ display: "flex", justifyContent: "space-between" }}><span className="mono">{e}</span><b>{fmtNum(n)}</b></div>)}
        </div>
        <div className="card">
          <h2 style={{ marginTop: 0 }}>أكثر عمليات البحث</h2>
          {a.top_searches.length === 0 ? <p className="muted">لا يوجد.</p> : a.top_searches.map((s) => (
            <div key={s.query} style={{ display: "flex", justifyContent: "space-between" }}><span>{s.query}</span><b>{fmtNum(s.n)}</b></div>
          ))}
        </div>
        <div className="card">
          <h2 style={{ marginTop: 0 }}>العرائس حسب المدينة</h2>
          {a.by_city.map((c) => <div key={c.city_id} style={{ display: "flex", justifyContent: "space-between" }}><span>{c.city_id}</span><b>{fmtNum(c.n)}</b></div>)}
          <h2>أكثر الأخطاء</h2>
          {a.top_errors.length === 0 ? <p className="muted">لا توجد أخطاء مسجلة.</p> : a.top_errors.map((e) => (
            <div key={e.code} className="small" style={{ display: "flex", justifyContent: "space-between" }}>
              <span className="mono">{e.code}</span><span>{fmtNum(e.n)} · {fmtDateTime(e.last)}</span>
            </div>
          ))}
        </div>
      </div>
    </>
  );
}
