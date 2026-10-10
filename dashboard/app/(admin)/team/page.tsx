import { supabaseServer } from "@/lib/supabase/server";
import { Flash } from "@/components/ui";
import { ConfirmButton } from "@/components/ConfirmButton";
import { fmtDate } from "@/lib/format";
import { addAdmin, setActive } from "./actions";

type AdminRow = { user_id: string; email: string; role_id: string; is_active: boolean; created_at: string };

export default async function Team({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const sp = await searchParams;
  const supabase = await supabaseServer();
  const [{ data: admins }, { data: roles }, { data: perms }] = await Promise.all([
    supabase.rpc("admin_list_admins"),
    supabase.from("admin_roles").select("id, name_ar"),
    supabase.from("admin_role_permissions").select("role_id, permission"),
  ]);
  const roleName = (id: string) => roles?.find((r) => r.id === id)?.name_ar ?? id;
  return (
    <>
      <div className="topbar"><h1>فريق الإدارة</h1></div>
      <Flash sp={sp} />
      <div className="table-wrap">
        <table>
          <thead><tr><th>البريد</th><th>الدور</th><th>منذ</th><th></th></tr></thead>
          <tbody>{((admins ?? []) as AdminRow[]).map((a) => (
            <tr key={a.user_id}>
              <td><span className="ltr">{a.email}</span> {!a.is_active && <span className="badge">موقوف</span>}</td>
              <td>{roleName(a.role_id)}</td>
              <td>{fmtDate(a.created_at)}</td>
              <td>
                <form action={setActive}>
                  <input type="hidden" name="user" value={a.user_id} />
                  <input type="hidden" name="active" value={a.is_active ? "false" : "true"} />
                  <ConfirmButton message="تأكيد؟" className="ghost">{a.is_active ? "إيقاف" : "تفعيل"}</ConfirmButton>
                </form>
              </td>
            </tr>
          ))}</tbody>
        </table>
      </div>
      <div className="grid two" style={{ marginTop: 16 }}>
        <form className="card stack" action={addAdmin}>
          <h2 style={{ margin: 0 }}>إضافة عضو</h2>
          <p className="muted small">أرسلي له دعوة أولاً من Supabase ← Authentication ← Invite user، ثم أضيفيه هنا بنفس البريد.</p>
          <label>البريد<input name="email" type="email" required dir="ltr" /></label>
          <label>الدور<select name="role">{(roles ?? []).map((r) => <option key={r.id} value={r.id}>{r.name_ar}</option>)}</select></label>
          <ConfirmButton message="إضافة هذا العضو للإدارة؟">إضافة</ConfirmButton>
        </form>
        <div className="card">
          <h2 style={{ marginTop: 0 }}>صلاحيات الأدوار</h2>
          <p className="small"><b>المالك</b>: كل الصلاحيات</p>
          {(roles ?? []).filter((r) => r.id !== "owner").map((r) => (
            <p key={r.id} className="small"><b>{r.name_ar}</b>: <span className="mono">{(perms ?? []).filter((p) => p.role_id === r.id).map((p) => p.permission).join("، ") || "—"}</span></p>
          ))}
        </div>
      </div>
    </>
  );
}
