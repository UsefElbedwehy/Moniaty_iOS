import Link from "next/link";
import { requireAdmin, can } from "@/lib/admin";
import { supabaseServer } from "@/lib/supabase/server";
import { i18n } from "@/lib/i18n";
import { LangSwitch } from "@/components/LangSwitch";
import { signOut } from "./actions";

type Queues = Record<string, number>;

export default async function AdminLayout({ children }: { children: React.ReactNode }) {
  const admin = await requireAdmin();
  const { t, lang } = await i18n();
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
        <div className="brand">{t("منيتي", "Munyati")}<small>{t("لوحة الإدارة", "Admin")}</small></div>
        <nav className="nav">
          <div className="nav-group">
            {item("/", t("الرئيسية", "Overview"))}
          </div>
          <div className="nav-group">
            <span>{t("العمليات", "Operations")}</span>
            {item("/providers?status=pending", t("مقدّمات الخدمة", "Providers"), q.providers_pending)}
            {item("/bookings", t("الحجوزات", "Bookings"))}
            {item("/disputes", t("النزاعات", "Disputes"), q.disputes_open)}
            {can(admin, "reviews.moderate") && item("/reviews", t("التقييمات", "Reviews"), q.reviews_pending)}
            {can(admin, "reports.handle") && item("/reports", t("البلاغات", "Reports"), q.reports_open)}
            {can(admin, "reports.handle") && item("/support", t("الدعم", "Support"), q.tickets_open)}
            {item("/users", t("المستخدمون", "Users"))}
          </div>
          <div className="nav-group">
            <span>{t("الإيرادات", "Revenue")}</span>
            {can(admin, "subscriptions.manage") && item("/subscriptions", t("الاشتراكات", "Subscriptions"), q.payments_review)}
            {can(admin, "subscriptions.manage") && item("/plans", t("الباقات", "Plans"))}
          </div>
          <div className="nav-group">
            <span>{t("المحتوى", "Content")}</span>
            {item("/catalog", t("المدن والأقسام", "Cities & categories"))}
            {item("/content", t("الصفحات والنصوص", "Pages & strings"))}
            {can(admin, "push.send") && item("/push", t("الإشعارات", "Push"))}
            {item("/settings", t("الإعدادات", "Settings"))}
          </div>
          <div className="nav-group">
            <span>{t("المتابعة", "Monitoring")}</span>
            {can(admin, "analytics.read") && item("/analytics", t("التحليلات", "Analytics"))}
            {can(admin, "audit.read") && item("/audit", t("سجل التعديلات", "Audit log"))}
            {can(admin, "team.manage") && item("/team", t("فريق الإدارة", "Admin team"))}
          </div>
        </nav>
        <div className="small" style={{ opacity: 0.75, margin: "24px 0 6px" }}>
          <span className="ltr">{admin.email}</span> · {admin.roleId}
        </div>
        <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
          <form action={signOut}>
            <button className="secondary" type="submit">{t("تسجيل الخروج", "Sign out")}</button>
          </form>
          <LangSwitch lang={lang} />
        </div>
      </aside>
      <main className="main">{children}</main>
    </div>
  );
}
