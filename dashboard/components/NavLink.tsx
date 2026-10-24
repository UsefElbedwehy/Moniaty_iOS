"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";

/**
 * A sidebar link that lights up on its own section: "/" only on the home page, any other link on
 * its path and the pages under it (e.g. /providers → /providers/<id>/services/<sid>).
 */
export function NavLink({ href, label, count }: { href: string; label: string; count?: number }) {
  const pathname = usePathname();
  const path = href.split("?")[0];
  const active = path === "/" ? pathname === "/" : pathname === path || pathname.startsWith(`${path}/`);
  return (
    <Link href={href} className={active ? "active" : undefined} aria-current={active ? "page" : undefined}>
      <span>{label}</span>
      {count ? <span className="count">{count}</span> : null}
    </Link>
  );
}
