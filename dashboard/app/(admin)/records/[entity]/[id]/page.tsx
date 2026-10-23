import Link from "next/link";
import { notFound } from "next/navigation";
import { supabaseServer } from "@/lib/supabase/server";
import { Flash } from "@/components/ui";
import { RecordActions } from "@/components/RecordActions";
import { isOwner } from "@/lib/admin";
import { i18n } from "@/lib/i18n";
import { ENTITIES, isEntity } from "@/lib/records";
import { param } from "@/lib/format";
import { updateRecord } from "../../actions";

/** Edit any record's editable fields, archive it, restore it, or delete it (owner). */
export default async function EditRecord({ params, searchParams }: {
  params: Promise<{ entity: string; id: string }>; searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const { entity, id } = await params;
  const sp = await searchParams;
  if (!isEntity(entity)) notFound();
  const config = ENTITIES[entity];
  const { t, lang, dateTime } = await i18n();
  const supabase = await supabaseServer();
  const { data: row } = await supabase.from(config.table).select(`${config.select}, archived_at`).eq("id", id).maybeSingle();
  if (!row) notFound();
  const record = row as unknown as Record<string, unknown>;
  const owner = await isOwner();
  const self = `/records/${entity}/${id}`;
  const back = param(sp.back) || config.href(record);
  const name = (pair: [string, string]) => (lang === "ar" ? pair[0] : pair[1]);
  const archivedAt = record.archived_at as string | null;

  return (
    <>
      <div className="topbar">
        <div>
          <span className="badge brand">{name(config.label)}</span>
          <h1 style={{ margin: "6px 0 0" }}>{config.title(record)}</h1>
          {archivedAt && <span className="badge warn">{t("مؤرشف منذ", "Archived since")} {dateTime(archivedAt)}</span>}
        </div>
        <Link className="button secondary" href={back}>{t("رجوع", "Back")}</Link>
      </div>
      <Flash sp={sp} />

      <div className="grid two">
        <div className="card">
          <h2 style={{ marginTop: 0 }}>{t("تعديل البيانات", "Edit details")}</h2>
          {(config.fields ?? []).length === 0 ? <p className="muted">{t("لا توجد حقول قابلة للتعديل لهذا النوع.", "This record type has no editable fields.")}</p> : (
            <form className="stack" action={updateRecord}>
              <input type="hidden" name="entity" value={entity} />
              <input type="hidden" name="id" value={id} />
              <input type="hidden" name="back" value={`${self}?back=${encodeURIComponent(back)}`} />
              {(config.fields ?? []).map((f) => {
                const value = record[f.name];
                if (f.type === "bool") return (
                  <label key={f.name} className="check"><input type="checkbox" name={f.name} defaultChecked={!!value} /> {name(f.label)}</label>
                );
                return (
                  <label key={f.name}>{name(f.label)}
                    {f.type === "textarea" ? <textarea name={f.name} defaultValue={(value as string) ?? ""} /> :
                     f.type === "select" ? (
                      <select name={f.name} defaultValue={(value as string) ?? ""}>
                        {(f.options ?? []).map(([v, ar, en]) => <option key={v} value={v}>{lang === "ar" ? ar : en}</option>)}
                      </select>
                     ) : <input name={f.name} type={f.type === "number" ? "number" : "text"} step="any" defaultValue={value == null ? "" : String(value)} />}
                  </label>
                );
              })}
              <button type="submit">{t("حفظ التعديلات", "Save changes")}</button>
            </form>
          )}
        </div>

        <div className="card">
          <h2 style={{ marginTop: 0 }}>{t("الأرشفة والحذف", "Archive and delete")}</h2>
          <p className="muted small">
            {t("الأرشفة تُخفي السجل من التطبيق ومن القوائم، ويمكن استعادته من صفحة «الأرشيف». الحذف النهائي لا يمكن التراجع عنه ومتاح للمالك فقط.",
               "Archiving hides the record from the app and the lists; restore it from the Archive page. Permanent delete can't be undone and is for the owner only.")}
          </p>
          <RecordActions entity={entity} id={id} archived={!!archivedAt} back={self} isOwner={owner} edit={false} />
          {entity === "user" || entity === "provider" ? (
            <p className="muted small" style={{ marginTop: 12 }}>
              {t("حذف الحساب يحذف معه نشاطه وخدماته ومتاجره وحجوزاته كمقدّمة خدمة.",
                 "Deleting the account also deletes its business, services, stores and bookings as a provider.")}
            </p>
          ) : null}
        </div>
      </div>
    </>
  );
}
