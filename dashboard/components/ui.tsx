import Link from "next/link";
import { i18n } from "@/lib/i18n";
import type { StatusMap } from "@/lib/labels";

export async function Badge({ map, value }: { map: StatusMap; value?: string | null }) {
  const { label } = await i18n();
  const tone = map[value ?? ""]?.[2] ?? "";
  return <span className={`badge ${tone}`}>{label(map, value)}</span>;
}

export function Stat({ label, value, alert, href }: { label: string; value: React.ReactNode; alert?: boolean; href?: string }) {
  const body = (
    <div className={`card stat${alert ? " alert" : ""}`}>
      <div className="label">{label}</div>
      <div className="value">{value}</div>
    </div>
  );
  return href ? <Link href={href} style={{ textDecoration: "none", color: "inherit" }}>{body}</Link> : body;
}

/** Success / error message from `?ok=` / `?err=` after a server action. */
export function Flash({ sp }: { sp: Record<string, string | string[] | undefined> }) {
  const ok = typeof sp.ok === "string" ? sp.ok : null;
  const err = typeof sp.err === "string" ? sp.err : null;
  if (err) return <div className="flash err">{err}</div>;
  if (ok) return <div className="flash ok">{ok}</div>;
  return null;
}

export function Chips({ base, current, options, name = "status" }: {
  base: string; current: string; options: [string, string][]; name?: string;
}) {
  return (
    <div className="chips">
      {options.map(([value, label]) => (
        <Link key={value} className={current === value ? "on" : ""} href={value ? `${base}?${name}=${value}` : base}>{label}</Link>
      ))}
    </div>
  );
}

export async function Pager({ base, page, hasMore, query }: { base: string; page: number; hasMore: boolean; query?: Record<string, string> }) {
  const { t } = await i18n();
  const link = (p: number) => `${base}?${new URLSearchParams({ ...(query ?? {}), page: String(p) })}`;
  if (page <= 1 && !hasMore) return null;
  return (
    <div className="pager">
      {page > 1 && <Link className="button secondary" href={link(page - 1)}>{t("السابق", "Previous")}</Link>}
      <span className="muted">{t("صفحة", "Page")} {page}</span>
      {hasMore && <Link className="button secondary" href={link(page + 1)}>{t("التالي", "Next")}</Link>}
    </div>
  );
}

export async function Empty({ text }: { text?: string }) {
  const { t } = await i18n();
  return <div className="empty">{text ?? t("لا توجد بيانات.", "No data.")}</div>;
}
