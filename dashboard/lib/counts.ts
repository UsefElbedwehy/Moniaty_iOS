import { supabaseServer } from "./supabase/server";

/**
 * How many rows of `table` have each value of `column` ("" counts them all), for filter chips.
 * `scope` adds the page's standing filters (e.g. archived records left out). Parallel head counts.
 */
export async function countBy(
  table: string, column: string, values: string[], scope: (q: any) => any = (q) => q,
): Promise<Record<string, number>> {
  const supabase = await supabaseServer();
  const entries = await Promise.all(values.map(async (value) => {
    let query = scope(supabase.from(table).select("*", { count: "exact", head: true }));
    if (value) query = query.eq(column, value);
    const { count } = await query;
    return [value, count ?? 0] as const;
  }));
  return Object.fromEntries(entries);
}

export const notArchived = (q: any) => q.is("archived_at", null);
