import { cache } from "react";
import { supabaseServer } from "./supabase/server";

export type Queues = {
  providers_pending: number; reviews_pending: number; reports_open: number;
  disputes_open: number; tickets_open: number; payments_review: number; receipts_duplicate: number;
};

/** What's waiting for an admin, archived records excluded. One set of counts per request. */
export const getQueues = cache(async (): Promise<Queues> => {
  const supabase = await supabaseServer();
  const count = async (table: string, apply: (q: any) => any) => {
    const { count } = await apply(supabase.from(table).select("id", { count: "exact", head: true }));
    return count ?? 0;
  };
  const [providers_pending, reviews_pending, reports_open, disputes_open, tickets_open, payments_review, receipts_duplicate] = await Promise.all([
    count("providers", (q) => q.eq("status", "pending").is("archived_at", null)),
    count("reviews", (q) => q.eq("status", "pending").is("archived_at", null)),
    count("reports", (q) => q.eq("status", "open").is("archived_at", null)),
    count("disputes", (q) => q.eq("status", "open")),
    count("support_tickets", (q) => q.eq("status", "open").is("archived_at", null)),
    count("subscription_payments", (q) => q.eq("status", "review")),
    count("payment_receipts", (q) => q.eq("is_duplicate", true)),
  ]);
  return { providers_pending, reviews_pending, reports_open, disputes_open, tickets_open, payments_review, receipts_duplicate };
});

export const totalQueue = (q: Queues) =>
  q.providers_pending + q.reviews_pending + q.reports_open + q.disputes_open + q.tickets_open + q.payments_review;
