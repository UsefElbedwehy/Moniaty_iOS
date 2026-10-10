import Link from "next/link";

export function Badge({ map, value }: { map: Record<string, [string, string]>; value?: string | null }) {
  const [label, tone] = map[value ?? ""] ?? [value ?? "—", ""];
  return <span className={`badge ${tone}`}>{label}</span>;
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

export function Pager({ base, page, hasMore, query }: { base: string; page: number; hasMore: boolean; query?: Record<string, string> }) {
  const link = (p: number) => `${base}?${new URLSearchParams({ ...(query ?? {}), page: String(p) })}`;
  if (page <= 1 && !hasMore) return null;
  return (
    <div className="pager">
      {page > 1 && <Link className="button secondary" href={link(page - 1)}>السابق</Link>}
      <span className="muted">صفحة {page}</span>
      {hasMore && <Link className="button secondary" href={link(page + 1)}>التالي</Link>}
    </div>
  );
}

export function Empty({ text = "لا توجد بيانات." }: { text?: string }) {
  return <div className="empty">{text}</div>;
}
