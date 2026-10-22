import { redirect, notFound } from "next/navigation";
import { supabaseServer } from "@/lib/supabase/server";

/** A reported service opens its photos and videos (to remove what breaks the rules); the
 *  provider's page, linked from there, can pause the whole service. */
export default async function ServiceRedirect({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const supabase = await supabaseServer();
  const { data } = await supabase.from("services").select("provider_id").eq("id", id).maybeSingle();
  if (!data) notFound();
  redirect(`/providers/${data.provider_id}/services/${id}`);
}
