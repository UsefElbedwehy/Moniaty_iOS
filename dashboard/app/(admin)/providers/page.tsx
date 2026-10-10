import Link from "next/link";
import { supabaseServer } from "@/lib/supabase/server";
import { Badge, Chips, Empty, Pager } from "@/components/ui";
import { fmtDate, param, pageRange, PAGE_SIZE } from "@/lib/format";
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
        <h1>مقدّمات الخدمة</h1>
        <form className="inline" action="/providers">
          {status && <input type="hidden" name="status" value={status} />}
          <input name="q" placeholder="بحث باسم النشاط" defaultValue={q} />
          <button className="secondary">بحث</button>
        </form>
      </div>
      <Chips base="/providers" current={status} options={[["", "الكل"], ["pending", "قيد المراجعة"], ["approved", "مفعّلة"], ["rejected", "مرفوضة"], ["suspended", "موقوفة"]]} />
      {error && <div className="flash err">{error.message}</div>}
      <div className="table-wrap">
        {rows.length === 0 ? <Empty /> : (
          <table>
            <thead><tr><th>النشاط</th><th>الجوال</th><th>الحالة</th><th>التوثيق</th><th>نهاية التجربة</th><th>التقييم</th><th>التسجيل</th></tr></thead>
            <tbody>
              {rows.map((p) => (
                <tr key={p.id}>
                  <td><Link href={`/providers/${p.id}`}>{p.business_name || p.profiles?.display_name || "بدون اسم"}</Link></td>
                  <td><span className="ltr">{p.profiles?.phone ?? "—"}</span></td>
                  <td><Badge map={providerStatus} value={p.status} /></td>
                  <td>{p.is_verified ? <span className="badge brand">موثّقة</span> : (p.cr_number || p.freelance_doc_number) ? <span className="badge warn">لديها وثيقة</span> : "—"}</td>
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
