import { redirect, notFound } from "next/navigation";
import { supabaseServer } from "@/lib/supabase/server";

/** A reported service opens its provider's page (where services can be paused). */
export default async function ServiceRedirect({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const supabase = await supabaseServer();
  const { data } = await supabase.from("services").select("provider_id").eq("id", id).maybeSingle();
  if (!data) notFound();
  redirect(`/providers/${data.provider_id}`);
}
