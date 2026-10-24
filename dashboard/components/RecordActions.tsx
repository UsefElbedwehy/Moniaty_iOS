import Link from "next/link";
import { ConfirmButton } from "@/components/ConfirmButton";
import { DeleteButton } from "@/components/DeleteButton";
import { i18n } from "@/lib/i18n";
import { ENTITIES, type Entity } from "@/lib/records";
import { archiveRecord, deleteRecord, restoreRecord } from "@/app/(admin)/records/actions";

/**
 * Edit · Archive / Restore · Delete for one record. Archive hides it everywhere and can be undone
 * from the Archive page; Delete is permanent and shown to owners only.
 */
export async function RecordActions({ entity, id, archived = false, back, isOwner, edit = true }: {
  entity: Entity; id: string; archived?: boolean; back: string; isOwner: boolean; edit?: boolean;
}) {
  const { t } = await i18n();
  const canEdit = edit && !!ENTITIES[entity].fields?.length;
  return (
    <form className="inline record-actions">
      <input type="hidden" name="entity" value={entity} />
      <input type="hidden" name="id" value={id} />
      <input type="hidden" name="back" value={back} />
      <input type="hidden" name="confirm" value="" />
      {canEdit && <Link className="button ghost" href={`/records/${entity}/${id}?back=${encodeURIComponent(back)}`}>{t("تعديل", "Edit")}</Link>}
      {archived ? (
        <ConfirmButton className="secondary" formAction={restoreRecord} message={t("استعادة هذا السجل؟", "Restore this record?")}>{t("استعادة", "Restore")}</ConfirmButton>
      ) : (
        <ConfirmButton className="ghost" formAction={archiveRecord}
          message={t("أرشفة هذا السجل؟ سيختفي من التطبيق ويمكن استعادته لاحقاً من صفحة الأرشيف.", "Archive this record? It disappears from the app and can be restored later from the Archive page.")}>
          {t("أرشفة", "Archive")}
        </ConfirmButton>
      )}
      {isOwner && (
        <DeleteButton formAction={deleteRecord} label={t("حذف نهائي", "Delete")}
          prompt={t("حذف نهائي لا يمكن التراجع عنه. اكتبي «حذف» للتأكيد:", "Permanent, can't be undone. Type DELETE to confirm:")} />
      )}
    </form>
  );
}
