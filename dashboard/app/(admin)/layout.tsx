import Link from "next/link";
import { requireAdmin, can } from "@/lib/admin";
import { i18n } from "@/lib/i18n";
import { LangSwitch } from "@/components/LangSwitch";
import { signOut } from "./actions";
import { getQueues, totalQueue } from "@/lib/queues";

export default async function AdminLayout({ children }: { children: React.ReactNode }) {
  const admin = await requireAdmin();
  const { t, lang } = await i18n();
  const q = await getQueues();

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
            {item("/", t("تحتاج إجراء", "Needs action"), totalQueue(q))}
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
            {item("/archive", t("الأرشيف", "Archive"))}
          </div>
          <div className="nav-group">
            <span>{t("الإيرادات", "Revenue")}</span>
            {can(admin, "subscriptions.manage") && item("/subscriptions", t("الاشتراكات", "Subscriptions"), q.payments_review)}
            {can(admin, "subscriptions.manage") && item("/plans", t("الباقات", "Plans"))}
          </div>
          <div className="nav-group">
            <span>{t("المحتوى", "Content")}</span>
            {item("/catalog", t("المدن والأقسام", "Cities & categories"))}
            {item("/banners", t("بنرات الرئيسية", "Home banners"))}
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
        <div className="sidebar-foot">
          <div className="small who"><span className="ltr">{admin.email}</span> · {admin.roleId}</div>
          <div className="actions">
            <form action={signOut}>
              <button className="secondary" type="submit">{t("تسجيل الخروج", "Sign out")}</button>
            </form>
            <LangSwitch lang={lang} />
          </div>
        </div>
      </aside>
      <main className="main">{children}</main>
    </div>
  );
}
