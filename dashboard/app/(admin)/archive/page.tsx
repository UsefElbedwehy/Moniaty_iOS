import Link from "next/link";
import { countBy, notArchived } from "@/lib/counts";
import { supabaseServer } from "@/lib/supabase/server";
import { Chips, Empty, Flash } from "@/components/ui";
import { RecordActions } from "@/components/RecordActions";
import { isOwner } from "@/lib/admin";
import { param } from "@/lib/format";
import { i18n } from "@/lib/i18n";
import { ENTITIES, isEntity, type Entity } from "@/lib/records";

type Row = { entity: string; entity_id: string; note: string | null; archived_at: string };

/** Everything archived from the dashboard, with Restore and (owner) permanent Delete. */
export default async function Archive({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const sp = await searchParams;
  const type = param(sp.type);
  const { t, lang, dateTime } = await i18n();
  const supabase = await supabaseServer();
  let query = supabase.from("admin_archive").select("entity, entity_id, note, archived_at").order("archived_at", { ascending: false }).limit(200);
  if (type) query = query.eq("entity", type);
  const rows = ((await query).data ?? []) as Row[];
  const owner = await isOwner();
  const back = `/archive${type ? `?type=${type}` : ""}`;

  // Names for the listed records, one query per record type.
  const titles = new Map<string, string>();
  const byEntity = new Map<Entity, string[]>();
  for (const r of rows) if (isEntity(r.entity)) byEntity.set(r.entity, [...(byEntity.get(r.entity) ?? []), r.entity_id]);
  await Promise.all([...byEntity].map(async ([entity, ids]) => {
    const config = ENTITIES[entity];
    const { data } = await supabase.from(config.table).select(config.select).in("id", ids);
    for (const rec of (data ?? []) as unknown as Record<string, unknown>[]) titles.set(`${entity}:${rec.id}`, config.title(rec));
  }));
  const name = (e: string) => (isEntity(e) ? ENTITIES[e].label[lang === "ar" ? 0 : 1] : e);

  const counts = await countBy("admin_archive", "entity", ["", "provider", "service", "store", "user", "booking", "review", "report", "ticket", "banner", "category", "city", "plan"]);
  return (
    <>
      <div className="topbar"><h1>{t("الأرشيف", "Archive")}</h1></div>
      <p className="muted">{t("السجلات المؤرشفة مخفية من التطبيق والقوائم. «استعادة» تعيدها كما كانت تماماً.", "Archived records are hidden from the app and the lists. Restore puts them back exactly as they were.")}</p>
      <Flash sp={sp} />
      <Chips base="/archive" current={type} name="type" options={[["", t("الكل", "All")],
        ...(["provider", "service", "store", "user", "booking", "review", "report", "ticket", "banner", "category", "city", "plan"] as Entity[])
          .map((e) => [e, name(e)] as [string, string])]}  counts={counts} />
      <div className="table-wrap">
        {rows.length === 0 ? <Empty /> : (
          <table>
            <thead><tr><th>{t("النوع", "Type")}</th><th>{t("السجل", "Record")}</th><th>{t("السبب", "Reason")}</th><th>{t("تاريخ الأرشفة", "Archived")}</th><th></th></tr></thead>
            <tbody>{rows.map((r) => (
              <tr key={`${r.entity}:${r.entity_id}`}>
                <td><span className="badge">{name(r.entity)}</span></td>
                <td>{isEntity(r.entity) ? <Link href={`/records/${r.entity}/${r.entity_id}?back=${encodeURIComponent(back)}`}>{titles.get(`${r.entity}:${r.entity_id}`) ?? r.entity_id}</Link> : r.entity_id}</td>
                <td className="muted">{r.note ?? "—"}</td>
                <td>{dateTime(r.archived_at)}</td>
                <td>{isEntity(r.entity) && <RecordActions entity={r.entity} id={r.entity_id} archived back={back} isOwner={owner} edit={false} />}</td>
              </tr>
            ))}</tbody>
          </table>
        )}
      </div>
    </>
  );
}
