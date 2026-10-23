"use server";
import { supabaseServer } from "@/lib/supabase/server";
import { done, rpcError, str, optStr, tr } from "@/lib/act";
import { DELETE_WORDS, ENTITIES, isEntity } from "@/lib/records";

/** Friendly text for the RPCs' refusal codes. */
async function refusal(code: string) {
  const map: Record<string, [string, string]> = {
    already_archived: ["السجل مؤرشف بالفعل", "Already archived"],
    not_archived: ["السجل غير مؤرشف", "Not archived"],
    in_use: ["لا يمكن الحذف لأنه مستخدم في سجلات أخرى؛ أرشفيه بدلاً من ذلك", "Can't delete: other records use it. Archive it instead"],
    is_admin: ["هذا الحساب من فريق الإدارة؛ أزيليه من الفريق أولاً", "This account is on the admin team; remove it from the team first"],
    field_not_editable: ["هذا الحقل غير قابل للتعديل", "That field can't be edited"],
  };
  const pair = map[code];
  return pair ? tr(pair[0], pair[1]) : code;
}

async function finish(back: string, result: { data: unknown; error: { message: string } | null }, ok: [string, string]) {
  const err = rpcError(result);
  return done(back, err ? { message: await refusal(err.message) } : null, ok);
}

export async function archiveRecord(form: FormData) {
  const supabase = await supabaseServer();
  const result = await supabase.rpc("admin_archive_record", { p_entity: str(form, "entity"), p_id: str(form, "id"), p_note: optStr(form, "note") });
  return finish(str(form, "back") || "/archive", result, ["تمت الأرشفة، ويمكن استعادته من صفحة الأرشيف", "Archived. Restore it from the Archive page"]);
}

export async function restoreRecord(form: FormData) {
  const supabase = await supabaseServer();
  const result = await supabase.rpc("admin_restore_record", { p_entity: str(form, "entity"), p_id: str(form, "id") });
  return finish(str(form, "back") || "/archive", result, ["تمت الاستعادة", "Restored"]);
}

export async function deleteRecord(form: FormData) {
  const back = str(form, "back") || "/archive";
  if (!DELETE_WORDS.includes(str(form, "confirm"))) {
    return done(back, { message: await tr("لم يتم الحذف: اكتبي كلمة «حذف» للتأكيد", "Not deleted: type DELETE to confirm") });
  }
  const supabase = await supabaseServer();
  const result = await supabase.rpc("admin_delete_record", { p_entity: str(form, "entity"), p_id: str(form, "id") });
  return finish(back, result, ["تم الحذف نهائياً", "Deleted permanently"]);
}

/** Saves the edit form: each configured field of the record type, typed for the database. */
export async function updateRecord(form: FormData) {
  const entity = str(form, "entity");
  const id = str(form, "id");
  const back = str(form, "back") || `/records/${entity}/${id}`;
  if (!isEntity(entity)) return done(back, { message: "unknown record type" });
  const changes: Record<string, unknown> = {};
  for (const field of ENTITIES[entity].fields ?? []) {
    if (field.type === "bool") { changes[field.name] = form.get(field.name) === "on"; continue; }
    const raw = form.get(field.name);
    if (raw === null) continue;
    const value = String(raw).trim();
    if (field.type === "number") changes[field.name] = value === "" ? null : Number(value);
    else changes[field.name] = value === "" ? null : value;
  }
  const supabase = await supabaseServer();
  const result = await supabase.rpc("admin_update_record", { p_entity: entity, p_id: id, p_changes: changes });
  return finish(back, result, ["تم الحفظ", "Saved"]);
}
