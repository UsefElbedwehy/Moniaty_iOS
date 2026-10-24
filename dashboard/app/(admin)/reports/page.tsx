import { countBy, notArchived } from "@/lib/counts";
import { RecordActions } from "@/components/RecordActions";
import { ReportCard } from "@/components/ReportCard";
import { isOwner } from "@/lib/admin";
import { supabaseServer } from "@/lib/supabase/server";
import { Chips, Empty, Flash } from "@/components/ui";
import { param } from "@/lib/format";
import { i18n } from "@/lib/i18n";
import { loadReportContext, type ReportRow } from "@/lib/reports";

export default async function Reports({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const sp = await searchParams;
  const status = param(sp.status, "open");
  const { t } = await i18n();
  const supabase = await supabaseServer();
  const { data } = await supabase.from("reports").select("*").eq("status", status).is("archived_at", null)
    .order("created_at", { ascending: status === "open" }).limit(100);
  const rows = (data ?? []) as ReportRow[];
  const ctx = await loadReportContext(supabase, rows);
  const back = `/reports?status=${status}`;

  const owner = await isOwner();
  const counts = await countBy("reports", "status", ["open", "actioned", "dismissed"], notArchived);
  return (
    <>
      <div className="topbar"><h1>{t("البلاغات", "Reports")}</h1><span className="muted">{t("الهدف: الإجراء خلال ٢٤ ساعة (إرشادات Apple)", "Goal: act within 24 hours (Apple guidelines)")}</span></div>
      <p className="muted">{t(
        "كل بلاغ يبيّن من أرسله، وما الذي أبلغ عنه، والسبب الذي اختاره، ورسالته بكلماته. افتحي المحتوى، اتخذي الإجراء المناسب (إخفاء تقييم، إيقاف خدمة، إيقاف مقدّمة خدمة…) ثم اكتبي ما فعلتِه واضغطي «تم الإجراء»، أو «رفض البلاغ» إن لم يكن هناك مخالفة.",
        "Each report shows who sent it, what they reported, the reason they picked and their own message. Open the content, act on it (hide a review, pause a service, suspend a provider…), then write what you did and press Actioned, or Dismiss if nothing was wrong.")}</p>
      <Flash sp={sp} />
      <Chips base="/reports" current={status} options={[["open", t("مفتوحة", "Open")], ["actioned", t("تم الإجراء", "Actioned")], ["dismissed", t("مرفوضة", "Dismissed")]]} counts={counts} />
      {rows.length === 0 ? <div className="card"><Empty text={t("لا توجد بلاغات.", "No reports.")} /></div> : rows.map((r) => (
        <ReportCard key={r.id} report={r} ctx={ctx} back={back}>
          <RecordActions entity="report" id={r.id} back={back} isOwner={owner} />
        </ReportCard>
      ))}
    </>
  );
}
