import Link from "next/link";
import { requireAdmin, can } from "@/lib/admin";
import { supabaseServer } from "@/lib/supabase/server";
import { signOut } from "./actions";

type Queues = Record<string, number>;

export default async function AdminLayout({ children }: { children: React.ReactNode }) {
  const admin = await requireAdmin();
  const supabase = await supabaseServer();
  const { data } = await supabase.rpc("admin_stats");
  const q: Queues = (data as { queues?: Queues } | null)?.queues ?? {};

  const item = (href: string, label: string, count?: number) => (
    <Link href={href}>
      <span>{label}</span>
      {count ? <span className="count">{count}</span> : null}
    </Link>
  );

  return (
    <div className="shell">
      <aside className="sidebar">
        <div className="brand">منيتي<small>لوحة الإدارة</small></div>
        <nav className="nav">
          <div className="nav-group">
            {item("/", "الرئيسية")}
          </div>
          <div className="nav-group">
            <span>العمليات</span>
            {item("/providers?status=pending", "مقدّمات الخدمة", q.providers_pending)}
            {item("/bookings", "الحجوزات")}
            {item("/disputes", "النزاعات", q.disputes_open)}
            {can(admin, "reviews.moderate") && item("/reviews", "التقييمات", q.reviews_pending)}
            {can(admin, "reports.handle") && item("/reports", "البلاغات", q.reports_open)}
            {can(admin, "reports.handle") && item("/support", "الدعم", q.tickets_open)}
            {item("/users", "المستخدمون")}
          </div>
          <div className="nav-group">
            <span>الإيرادات</span>
            {can(admin, "subscriptions.manage") && item("/subscriptions", "الاشتراكات", q.payments_review)}
            {can(admin, "subscriptions.manage") && item("/plans", "الباقات")}
          </div>
          <div className="nav-group">
            <span>المحتوى</span>
            {item("/catalog", "المدن والأقسام")}
            {item("/content", "الصفحات والنصوص")}
            {can(admin, "push.send") && item("/push", "الإشعارات")}
            {item("/settings", "الإعدادات")}
          </div>
          <div className="nav-group">
            <span>المتابعة</span>
            {can(admin, "analytics.read") && item("/analytics", "التحليلات")}
            {can(admin, "audit.read") && item("/audit", "سجل التعديلات")}
            {can(admin, "team.manage") && item("/team", "فريق الإدارة")}
          </div>
        </nav>
        <form action={signOut} style={{ marginTop: 24 }}>
          <div className="small" style={{ opacity: 0.75, marginBottom: 6 }}>
            <span className="ltr">{admin.email}</span> · {admin.roleId}
          </div>
          <button className="secondary" type="submit">تسجيل الخروج</button>
        </form>
      </aside>
      <main className="main">{children}</main>
    </div>
  );
}
