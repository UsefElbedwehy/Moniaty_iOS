import { redirect, notFound } from "next/navigation";
import { supabaseServer } from "@/lib/supabase/server";

export default async function StoreRedirect({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const supabase = await supabaseServer();
  const { data } = await supabase.from("stores").select("provider_id").eq("id", id).maybeSingle();
  if (!data) notFound();
  redirect(`/providers/${data.provider_id}`);
}
