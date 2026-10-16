import Link from "next/link";
import { supabaseServer } from "@/lib/supabase/server";
import { Badge, Chips, Empty, Pager } from "@/components/ui";
import { param, pageRange, PAGE_SIZE } from "@/lib/format";
import { i18n } from "@/lib/i18n";
import { providerStatus } from "@/lib/labels";

type Row = {
  id: string; status: string; business_name: string | null; is_verified: boolean; created_at: string;
  trial_ends_at: string | null; cr_number: string | null; freelance_doc_number: string | null; rating_avg: number | null;
  profiles: { phone: string | null; display_name: string | null } | null;
};

export default async function Providers({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const sp = await searchParams;
  const status = param(sp.status);
  const q = param(sp.q);
  const page = Math.max(1, Number(param(sp.page, "1")) || 1);
  const { t, date: fmtDate } = await i18n();
  const supabase = await supabaseServer();
  let query = supabase.from("providers")
    .select("id, status, business_name, is_verified, created_at, trial_ends_at, cr_number, freelance_doc_number, rating_avg, profiles!providers_id_fkey(phone, display_name)")
    .order("created_at", { ascending: status !== "pending" ? false : true })
    .range(...pageRange(page));
  if (status) query = query.eq("status", status);
  if (q) query = query.ilike("business_name", `%${q}%`);
  const { data, error } = await query;
  const rows = (data ?? []) as unknown as Row[];

  return (
    <>
      <div className="topbar">
        <h1>{t("مقدّمات الخدمة", "Providers")}</h1>
        <form className="inline" action="/providers">
          {status && <input type="hidden" name="status" value={status} />}
          <input name="q" placeholder={t("بحث باسم النشاط", "Search by business name")} defaultValue={q} />
          <button className="secondary">{t("بحث", "Search")}</button>
        </form>
      </div>
      <Chips base="/providers" current={status} options={[["", t("الكل", "All")], ["pending", t("قيد المراجعة", "Pending")], ["approved", t("مفعّلة", "Approved")], ["rejected", t("مرفوضة", "Rejected")], ["suspended", t("موقوفة", "Suspended")]]} />
      {error && <div className="flash err">{error.message}</div>}
      <div className="table-wrap">
        {rows.length === 0 ? <Empty /> : (
          <table>
            <thead><tr><th>{t("النشاط", "Business")}</th><th>{t("الجوال", "Mobile")}</th><th>{t("الحالة", "Status")}</th><th>{t("التوثيق", "Verification")}</th><th>{t("نهاية التجربة", "Trial ends")}</th><th>{t("التقييم", "Rating")}</th><th>{t("التسجيل", "Joined")}</th></tr></thead>
            <tbody>
              {rows.map((p) => (
                <tr key={p.id}>
                  <td><Link href={`/providers/${p.id}`}>{p.business_name || p.profiles?.display_name || t("بدون اسم", "Unnamed")}</Link></td>
                  <td><span className="ltr">{p.profiles?.phone ?? "—"}</span></td>
                  <td><Badge map={providerStatus} value={p.status} /></td>
                  <td>{p.is_verified ? <span className="badge brand">{t("موثّقة", "Verified")}</span> : (p.cr_number || p.freelance_doc_number) ? <span className="badge warn">{t("لديها وثيقة", "Has document")}</span> : "—"}</td>
                  <td>{fmtDate(p.trial_ends_at)}</td>
                  <td>{p.rating_avg ?? "—"}</td>
                  <td>{fmtDate(p.created_at)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
      <Pager base="/providers" page={page} hasMore={rows.length === PAGE_SIZE} query={{ status, q }} />
    </>
  );
}
