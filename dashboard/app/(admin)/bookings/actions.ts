"use server";
import { supabaseServer } from "@/lib/supabase/server";
import { done, rpcError, str } from "@/lib/act";

export async function resolveDispute(form: FormData) {
  const booking = str(form, "booking");
  const supabase = await supabaseServer();
  const result = await supabase.rpc("admin_resolve_dispute", {
    p_dispute: str(form, "dispute"), p_outcome: str(form, "outcome"), p_note: str(form, "note"),
  });
  done(`/bookings/${booking}`, rpcError(result), "تم إغلاق النزاع وإشعار الطرفين");
}
