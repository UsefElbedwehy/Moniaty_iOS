import type { SupabaseClient } from "@supabase/supabase-js";

/** A report as stored: who reported which thing, why, and in her own words. */
export type ReportRow = {
  id: string; reporter_id: string | null; target_type: string; target_id: string; reason: string;
  details: string | null; status: string; resolution_note: string | null; handled_at?: string | null; created_at: string;
};

export type Person = { id: string; name: string | null; phone: string | null; role: string | null; deleted: boolean };

/** The reported thing in words an admin recognises, with where to open it. */
export type Target = { title: string | null; subtitle: string | null; href: string; rating?: number | null };

export type ReportContext = { reporters: Map<string, Person>; targets: Map<string, Target> };

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const key = (type: string, id: string) => `${type}:${id}`;

type ProfileRow = { id: string; display_name: string | null; first_name: string | null; last_name: string | null;
  phone: string | null; role: string | null; deleted_at: string | null };
const person = (p: ProfileRow): Person => ({
  id: p.id,
  name: p.display_name || [p.first_name, p.last_name].filter(Boolean).join(" ") || null,
  phone: p.phone, role: p.role, deleted: !!p.deleted_at,
});

/**
 * Loads, in one round of queries, the reporter of each report and a readable summary of what she
 * reported (the provider's business name, the service title, the review text…). Anything the
 * admin can't read, or that no longer exists, is simply missing from the maps.
 */
export async function loadReportContext(supabase: SupabaseClient, reports: ReportRow[]): Promise<ReportContext> {
  const idsOf = (type: string) => [...new Set(reports.filter((r) => r.target_type === type).map((r) => r.target_id).filter((id) => UUID.test(id)))];
  const profileIds = [...new Set([...reports.map((r) => r.reporter_id).filter((id): id is string => !!id), ...idsOf("user")])];
  const none = Promise.resolve({ data: [] as unknown[] });

  const [profiles, providers, services, stores, reviews, bookings] = await Promise.all([
    profileIds.length ? supabase.from("profiles").select("id, display_name, first_name, last_name, phone, role, deleted_at").in("id", profileIds) : none,
    idsOf("provider").length ? supabase.from("providers").select("id, business_name").in("id", idsOf("provider")) : none,
    idsOf("service").length ? supabase.from("services").select("id, title, providers(business_name)").in("id", idsOf("service")) : none,
    idsOf("store").length ? supabase.from("stores").select("id, name, providers(business_name)").in("id", idsOf("store")) : none,
    idsOf("review").length ? supabase.from("reviews").select("id, rating, body, provider_id, providers(business_name)").in("id", idsOf("review")) : none,
    idsOf("booking").length ? supabase.from("bookings").select("id, reference_code, service_title").in("id", idsOf("booking")) : none,
  ]);

  const reporters = new Map<string, Person>();
  const targets = new Map<string, Target>();
  for (const p of (profiles.data ?? []) as ProfileRow[]) {
    reporters.set(p.id, person(p));
    const who = person(p);
    targets.set(key("user", p.id), { title: who.name, subtitle: who.phone, href: `/users?q=${encodeURIComponent(who.phone ?? p.id)}` });
  }
  for (const p of (providers.data ?? []) as { id: string; business_name: string | null }[]) {
    targets.set(key("provider", p.id), { title: p.business_name, subtitle: null, href: `/providers/${p.id}` });
  }
  type Owned = { providers: { business_name: string | null } | null };
  for (const s of (services.data ?? []) as unknown as ({ id: string; title: string } & Owned)[]) {
    targets.set(key("service", s.id), { title: s.title, subtitle: s.providers?.business_name ?? null, href: `/reports/service/${s.id}` });
  }
  for (const s of (stores.data ?? []) as unknown as ({ id: string; name: string } & Owned)[]) {
    targets.set(key("store", s.id), { title: s.name, subtitle: s.providers?.business_name ?? null, href: `/reports/store/${s.id}` });
  }
  for (const r of (reviews.data ?? []) as unknown as ({ id: string; rating: number; body: string | null; provider_id: string } & Owned)[]) {
    targets.set(key("review", r.id), { title: r.body, subtitle: r.providers?.business_name ?? null, href: `/providers/${r.provider_id}`, rating: r.rating });
  }
  for (const b of (bookings.data ?? []) as { id: string; reference_code: string; service_title: string | null }[]) {
    targets.set(key("booking", b.id), { title: b.reference_code, subtitle: b.service_title, href: `/bookings/${b.id}` });
  }
  return { reporters, targets };
}

export const targetOf = (ctx: ReportContext, r: ReportRow) => ctx.targets.get(key(r.target_type, r.target_id));
