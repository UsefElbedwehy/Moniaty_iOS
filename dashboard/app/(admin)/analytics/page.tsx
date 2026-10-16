import { supabaseServer } from "@/lib/supabase/server";
import { Chips } from "@/components/ui";
import { param } from "@/lib/format";
import { i18n } from "@/lib/i18n";
import type { LabelMap } from "@/lib/labels";

type Analytics = {
  daily: { day: string; event: string; n: number }[];
  signups: { day: string; role: string; n: number }[];
  funnel: Record<string, number>;
  top_searches: { query: string; n: number }[];
  top_errors: { code: string; n: number; last: string }[];
  by_city: { city_id: string; n: number }[];
};

const funnelSteps: LabelMap = {
  service_views: ["مشاهدات الخدمات", "Service views"], booking_started: ["ضغط «احجزي»", "Tapped “Book”"], requested: ["طلبات حجز", "Requests"],
  approved: ["تمت الموافقة", "Approved"], paid: ["مدفوعة", "Paid"], completed: ["مكتملة", "Completed"],
};

/** A small bar chart per day, no chart library. */
async function DailyBars({ points, label }: { points: { day: string; n: number }[]; label: string }) {
  const { t } = await i18n();
  const max = Math.max(1, ...points.map((p) => p.n));
  return (
    <div className="card">
      <h2 style={{ marginTop: 0 }}>{label}</h2>
      {points.length === 0 ? <p className="muted">{t("لا توجد بيانات.", "No data.")}</p> : (
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
  const { t, label: labelOf, num: fmtNum, dateTime: fmtDateTime } = await i18n();
  const supabase = await supabaseServer();
  const { data, error } = await supabase.rpc("admin_analytics", { p_days: Number(days) });
  if (error || !data) return <div className="flash err">{error?.message}</div>;
  const a = data as Analytics;
  const top = a.funnel.service_views || 1;
  const eventTotals = Object.entries(a.daily.reduce<Record<string, number>>((acc, r) => ({ ...acc, [r.event]: (acc[r.event] ?? 0) + r.n }), {}))
    .sort((x, y) => y[1] - x[1]);

  return (
    <>
      <div className="topbar"><h1>{t("التحليلات", "Analytics")}</h1><span className="muted small">{t("تفاصيل الشاشات والضغطات في Firebase Analytics، والأعطال في Crashlytics.", "Screen and tap details are in Firebase Analytics; crashes in Crashlytics.")}</span></div>
      <Chips base="/analytics" name="days" current={days} options={[["7", t("٧ أيام", "7 days")], ["30", t("٣٠ يوم", "30 days")], ["90", t("٩٠ يوم", "90 days")]]} />
      <div className="grid two">
        <DailyBars label={t("التسجيلات اليومية", "Daily sign-ups")} points={sumByDay(a.signups)} />
        <DailyBars label={t("الأحداث اليومية", "Daily events")} points={sumByDay(a.daily)} />
      </div>
      <div className="grid two" style={{ marginTop: 12 }}>
        <div className="card">
          <h2 style={{ marginTop: 0 }}>{t("مسار الحجز", "Booking funnel")}</h2>
          {Object.keys(funnelSteps).map((k) => (
            <div key={k} style={{ marginBottom: 8 }}>
              <div style={{ display: "flex", justifyContent: "space-between" }}><span>{labelOf(funnelSteps, k)}</span><b>{fmtNum(a.funnel[k])}</b></div>
              <div className="bar"><i style={{ width: `${Math.min(100, ((a.funnel[k] ?? 0) / top) * 100)}%` }} /></div>
            </div>
          ))}
          <p className="muted small">{t("الحجوزات التجريبية مستبعدة.", "Demo bookings are excluded.")}</p>
        </div>
        <div className="card">
          <h2 style={{ marginTop: 0 }}>{t("الأحداث", "Events")}</h2>
          {eventTotals.map(([e, n]) => <div key={e} style={{ display: "flex", justifyContent: "space-between" }}><span className="mono">{e}</span><b>{fmtNum(n)}</b></div>)}
        </div>
        <div className="card">
          <h2 style={{ marginTop: 0 }}>{t("أكثر عمليات البحث", "Top searches")}</h2>
          {a.top_searches.length === 0 ? <p className="muted">{t("لا يوجد.", "None.")}</p> : a.top_searches.map((s) => (
            <div key={s.query} style={{ display: "flex", justifyContent: "space-between" }}><span>{s.query}</span><b>{fmtNum(s.n)}</b></div>
          ))}
        </div>
        <div className="card">
          <h2 style={{ marginTop: 0 }}>{t("العرائس حسب المدينة", "Brides by city")}</h2>
          {a.by_city.map((c) => <div key={c.city_id} style={{ display: "flex", justifyContent: "space-between" }}><span>{c.city_id}</span><b>{fmtNum(c.n)}</b></div>)}
          <h2>{t("أكثر الأخطاء", "Top errors")}</h2>
          {a.top_errors.length === 0 ? <p className="muted">{t("لا توجد أخطاء مسجلة.", "No errors logged.")}</p> : a.top_errors.map((e) => (
            <div key={e.code} className="small" style={{ display: "flex", justifyContent: "space-between" }}>
              <span className="mono">{e.code}</span><span>{fmtNum(e.n)} · {fmtDateTime(e.last)}</span>
            </div>
          ))}
        </div>
      </div>
    </>
  );
}
