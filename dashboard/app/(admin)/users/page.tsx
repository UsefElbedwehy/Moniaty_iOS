import Link from "next/link";
import { supabaseServer } from "@/lib/supabase/server";
import { Chips, Empty, Flash, Pager } from "@/components/ui";
import { ConfirmButton } from "@/components/ConfirmButton";
import { fmtDate, param, pageRange, PAGE_SIZE } from "@/lib/format";
import { role as roleLabel } from "@/lib/labels";
import { setBan } from "../reviews/actions";

type User = { id: string; phone: string | null; display_name: string | null; role: string; is_banned: boolean;
  created_at: string; deleted_at: string | null; sms_marketing_opt_in: boolean };

export default async function Users({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const sp = await searchParams;
  const role = param(sp.role);
  const q = param(sp.q);
  const page = Math.max(1, Number(param(sp.page, "1")) || 1);
  const supabase = await supabaseServer();
  let query = supabase.from("profiles").select("id, phone, display_name, role, is_banned, created_at, deleted_at, sms_marketing_opt_in")
    .order("created_at", { ascending: false }).range(...pageRange(page));
  if (role) query = query.eq("role", role);
  if (q) {
    const safe = q.replace(/[,()]/g, " ");
    query = /^[0-9a-f-]{36}$/i.test(q) ? query.eq("id", q) : query.or(`phone.ilike.%${safe}%,display_name.ilike.%${safe}%`);
  }
  const { data } = await query;
  const rows = (data ?? []) as User[];
  const back = `/users?${new URLSearchParams({ role, q })}`;

  return (
    <>
      <div className="topbar">
        <h1>المستخدمون</h1>
        <form className="inline" action="/users">
          {role && <input type="hidden" name="role" value={role} />}
          <input name="q" placeholder="جوال أو اسم" defaultValue={q} />
          <button className="secondary">بحث</button>
        </form>
      </div>
      <Flash sp={sp} />
      <Chips base="/users" current={role} name="role" options={[["", "الكل"], ["bride", "العرائس"], ["provider", "مقدّمات الخدمة"]]} />
      <div className="table-wrap">
        {rows.length === 0 ? <Empty /> : (
          <table>
            <thead><tr><th>الاسم</th><th>الجوال</th><th>الدور</th><th>رسائل تسويقية</th><th>التسجيل</th><th></th></tr></thead>
            <tbody>{rows.map((u) => (
              <tr key={u.id}>
                <td>
                  {u.role === "provider" ? <Link href={`/providers/${u.id}`}>{u.display_name ?? "—"}</Link> : u.display_name ?? "—"}
                  {u.deleted_at && <span className="badge"> محذوف</span>}
                  {u.is_banned && <span className="badge bad"> ممنوع من التقييم</span>}
                </td>
                <td><span className="ltr">{u.phone ?? "—"}</span></td>
                <td>{roleLabel[u.role] ?? u.role}</td>
                <td>{u.sms_marketing_opt_in ? "نعم" : "لا"}</td>
                <td>{fmtDate(u.created_at)}</td>
                <td>
                  <form action={setBan}>
                    <input type="hidden" name="user" value={u.id} />
                    <input type="hidden" name="banned" value={u.is_banned ? "false" : "true"} />
                    <input type="hidden" name="back_path" value={back} />
                    <ConfirmButton message="تأكيد؟" className="ghost">{u.is_banned ? "رفع المنع" : "منع من التقييم"}</ConfirmButton>
                  </form>
                </td>
              </tr>
            ))}</tbody>
          </table>
        )}
      </div>
      <Pager base="/users" page={page} hasMore={rows.length === PAGE_SIZE} query={{ role, q }} />
    </>
  );
}
