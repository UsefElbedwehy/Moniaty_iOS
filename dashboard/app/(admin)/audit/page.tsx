import { supabaseServer } from "@/lib/supabase/server";
import { Empty, Pager } from "@/components/ui";
import { fmtDateTime, param, pageRange, PAGE_SIZE } from "@/lib/format";

type Row = { id: number; admin_id: string | null; action: string; entity_type: string; entity_id: string | null;
  before: unknown; after: unknown; created_at: string };

export default async function Audit({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const sp = await searchParams;
  const entity = param(sp.entity);
  const page = Math.max(1, Number(param(sp.page, "1")) || 1);
  const supabase = await supabaseServer();
  let query = supabase.from("admin_audit_log").select("*").order("created_at", { ascending: false }).range(...pageRange(page));
  if (entity) query = query.eq("entity_type", entity);
  const [{ data }, { data: admins }] = await Promise.all([query, supabase.rpc("admin_list_admins")]);
  const rows = (data ?? []) as Row[];
  const email = (id: string | null) => ((admins ?? []) as { user_id: string; email: string }[]).find((a) => a.user_id === id)?.email ?? "النظام";
  return (
    <>
      <div className="topbar">
        <h1>سجل التعديلات</h1>
        <form className="inline" action="/audit">
          <input name="entity" placeholder="الجدول (providers، app_config…)" defaultValue={entity} dir="ltr" />
          <button className="secondary">تصفية</button>
        </form>
      </div>
      <div className="table-wrap">
        {rows.length === 0 ? <Empty /> : (
          <table>
            <thead><tr><th>الوقت</th><th>المشرف</th><th>الإجراء</th><th>الجدول</th><th>المعرّف</th><th>التفاصيل</th></tr></thead>
            <tbody>{rows.map((r) => (
              <tr key={r.id}>
                <td>{fmtDateTime(r.created_at)}</td>
                <td><span className="ltr small">{email(r.admin_id)}</span></td>
                <td>{r.action}</td>
                <td className="mono">{r.entity_type}</td>
                <td className="mono">{r.entity_id?.slice(0, 12)}</td>
                <td><details><summary>عرض</summary><pre className="mono" style={{ maxWidth: 480, overflow: "auto", direction: "ltr" }}>{JSON.stringify({ before: r.before, after: r.after }, null, 2)}</pre></details></td>
              </tr>
            ))}</tbody>
          </table>
        )}
      </div>
      <Pager base="/audit" page={page} hasMore={rows.length === PAGE_SIZE} query={{ entity }} />
    </>
  );
}
