"use server";
import { supabaseServer } from "@/lib/supabase/server";
import { done, rpcError, str, bool } from "@/lib/act";

export async function replyTicket(form: FormData) {
  const supabase = await supabaseServer();
  const result = await supabase.rpc("admin_reply_ticket", {
    p_ticket: str(form, "id"), p_reply: str(form, "reply"), p_close: bool(form, "close"),
  });
  done("/support", rpcError(result), "تم إرسال الرد");
}
