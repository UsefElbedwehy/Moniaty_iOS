import Link from "next/link";
import { countBy, notArchived } from "@/lib/counts";
import { supabaseServer } from "@/lib/supabase/server";
import { Badge, Chips, Empty, Pager } from "@/components/ui";
import { param, pageRange, PAGE_SIZE } from "@/lib/format";
import { i18n } from "@/lib/i18n";
import { paymentStatus } from "@/lib/labels";
import { isDeveloper } from "@/lib/admin";

type Payment = { id: string; provider_id: string | null; plan_id: string; amount: number; currency: string; status: string;
  tap_charge_id: string | null; tap_status: string | null; created_at: string; captured_at: string | null; raw: unknown;
  providers: { business_name: string | null } | null };

export default async function Subscriptions({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const sp = await searchParams;
  const status = param(sp.status, "captured");
  const page = Math.max(1, Number(param(sp.page, "1")) || 1);
  const { t, dateTime: fmtDateTime, sar: fmtSAR } = await i18n();
  const supabase = await supabaseServer();
  // The raw Tap response is shown to the developer only.
  const developer = await isDeveloper();
  let query = supabase.from("subscription_payments").select("*, providers(business_name)")
    .order("created_at", { ascending: false }).range(...pageRange(page));
  if (status) query = query.eq("status", status);
  const { data } = await query;
  const rows = (data ?? []) as unknown as Payment[];
  const total = rows.filter((r) => r.status === "captured").reduce((a, r) => a + Number(r.amount), 0);

  const counts = await countBy("subscription_payments", "status", ["captured", "review", "failed", "initiated", ""]);
  return (
    <>
      <div className="topbar"><h1>{t("مدفوعات الاشتراكات (Tap)", "Subscription payments (Tap)")}</h1>{status === "captured" && <span className="badge good">{t("مجموع الصفحة:", "Page total:")} {fmtSAR(total)}</span>}</div>
      <p className="muted">{t("الحالة «مدفوعة» يضعها الخادم فقط بعد التحقق من Tap مباشرة. «تحتاج مراجعة» تعني أن المبلغ أو العملة لم تطابق الباقة.", "Only the server sets “Paid”, after checking with Tap directly. “Needs review” means the amount or currency didn't match the plan.")}</p>
      <Chips base="/subscriptions" current={status} options={[["captured", t("مدفوعة", "Paid")], ["review", t("تحتاج مراجعة", "Needs review")], ["failed", t("فشلت", "Failed")], ["initiated", t("لم تكتمل", "Not completed")], ["", t("الكل", "All")]]}  counts={counts} />
      <div className="table-wrap">
        {rows.length === 0 ? <Empty /> : (
          <table>
            <thead><tr><th>{t("التاريخ", "Date")}</th><th>{t("مقدّمة الخدمة", "Provider")}</th><th>{t("الباقة", "Plan")}</th><th>{t("المبلغ", "Amount")}</th><th>{t("الحالة", "Status")}</th><th>Tap</th>{developer && <th></th>}</tr></thead>
            <tbody>{rows.map((r) => (
              <tr key={r.id}>
                <td>{fmtDateTime(r.captured_at ?? r.created_at)}</td>
                <td>{r.provider_id ? <Link href={`/providers/${r.provider_id}`}>{r.providers?.business_name ?? "—"}</Link> : t("محذوف", "Deleted")}</td>
                <td>{r.plan_id}</td>
                <td>{fmtSAR(r.amount)}</td>
                <td><Badge map={paymentStatus} value={r.status} /></td>
                <td><span className="mono ltr">{r.tap_charge_id ?? "—"}</span> <span className="small muted">{r.tap_status}</span></td>
                {developer && <td>{r.raw ? <details><summary>{t("التفاصيل", "Details")}</summary><pre className="mono" style={{ maxWidth: 420, overflow: "auto", direction: "ltr" }}>{JSON.stringify(r.raw, null, 2)}</pre></details> : null}</td>}
              </tr>
            ))}</tbody>
          </table>
        )}
      </div>
      <Pager base="/subscriptions" page={page} hasMore={rows.length === PAGE_SIZE} query={{ status }} />
    </>
  );
}
