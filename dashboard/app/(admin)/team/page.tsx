import { supabaseServer } from "@/lib/supabase/server";
import { Flash } from "@/components/ui";
import { ConfirmButton } from "@/components/ConfirmButton";
import { i18n } from "@/lib/i18n";
import { addAdmin, setActive } from "./actions";

type AdminRow = { user_id: string; email: string; role_id: string; is_active: boolean; created_at: string };

export default async function Team({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const sp = await searchParams;
  const { t, lang, list, arrow, date: fmtDate } = await i18n();
  const supabase = await supabaseServer();
  const [{ data: admins }, { data: roles }, { data: perms }] = await Promise.all([
    supabase.rpc("admin_list_admins"),
    supabase.from("admin_roles").select("id, name_ar, name_en"),
    supabase.from("admin_role_permissions").select("role_id, permission"),
  ]);
  const nameOf = (r: { name_ar: string; name_en: string }) => (lang === "ar" ? r.name_ar : r.name_en);
  const roleName = (id: string) => { const r = roles?.find((x) => x.id === id); return r ? nameOf(r) : id; };
  return (
    <>
      <div className="topbar"><h1>{t("فريق الإدارة", "Admin team")}</h1></div>
      <Flash sp={sp} />
      <div className="table-wrap">
        <table>
          <thead><tr><th>{t("البريد", "Email")}</th><th>{t("الدور", "Role")}</th><th>{t("منذ", "Since")}</th><th></th></tr></thead>
          <tbody>{((admins ?? []) as AdminRow[]).map((a) => (
            <tr key={a.user_id}>
              <td><span className="ltr">{a.email}</span> {!a.is_active && <span className="badge">{t("موقوف", "Suspended")}</span>}</td>
              <td>{roleName(a.role_id)}</td>
              <td>{fmtDate(a.created_at)}</td>
              <td>
                <form action={setActive}>
                  <input type="hidden" name="user" value={a.user_id} />
                  <input type="hidden" name="active" value={a.is_active ? "false" : "true"} />
                  <ConfirmButton message={t("تأكيد؟", "Are you sure?")} className="ghost">{a.is_active ? t("إيقاف", "Suspend") : t("تفعيل", "Activate")}</ConfirmButton>
                </form>
              </td>
            </tr>
          ))}</tbody>
        </table>
      </div>
      <div className="grid two">
        <form className="card stack" action={addAdmin}>
          <h2 style={{ margin: 0 }}>{t("إضافة عضو", "Add a member")}</h2>
          <p className="muted small">{t("أرسلي له دعوة أولاً من Supabase", "First invite them in Supabase")} {arrow} Authentication {arrow} Invite user{t("، ثم أضيفيه هنا بنفس البريد.", ", then add them here with the same email.")}</p>
          <label>{t("البريد", "Email")}<input name="email" type="email" required dir="ltr" /></label>
          <label>{t("الدور", "Role")}<select name="role">{(roles ?? []).map((r) => <option key={r.id} value={r.id}>{nameOf(r)}</option>)}</select></label>
          <ConfirmButton message={t("إضافة هذا العضو للإدارة؟", "Add this member to the admin team?")}>{t("إضافة", "Add")}</ConfirmButton>
        </form>
        <div className="card">
          <h2 style={{ marginTop: 0 }}>{t("صلاحيات الأدوار", "Role permissions")}</h2>
          <p className="small"><b>{t("المالك", "Owner")}</b>: {t("كل الصلاحيات", "all permissions")}</p>
          {(roles ?? []).filter((r) => r.id !== "owner").map((r) => (
            <p key={r.id} className="small"><b>{nameOf(r)}</b>: <span className="mono">{list((perms ?? []).filter((p) => p.role_id === r.id).map((p) => p.permission)) || "—"}</span></p>
          ))}
        </div>
      </div>
    </>
  );
}
