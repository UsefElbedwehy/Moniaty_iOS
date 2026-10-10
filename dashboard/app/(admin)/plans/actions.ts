"use server";
import { supabaseServer } from "@/lib/supabase/server";
import { done, str, optStr, bool, num } from "@/lib/act";

const lines = (v: string) => v.split("\n").map((s) => s.trim()).filter(Boolean);

export async function savePlan(form: FormData) {
  const supabase = await supabaseServer();
  const { error } = await supabase.from("subscription_plans").update({
    name_ar: str(form, "name_ar"), name_en: str(form, "name_en"),
    description_ar: optStr(form, "description_ar"), description_en: optStr(form, "description_en"),
    features_ar: lines(str(form, "features_ar")), features_en: lines(str(form, "features_en")),
    price_sar: num(form, "price_sar"), max_services: num(form, "max_services"), max_stores: num(form, "max_stores"),
    max_photos_per_service: num(form, "max_photos_per_service"), search_boost: num(form, "search_boost"),
    is_featured: bool(form, "is_featured"), is_recommended: bool(form, "is_recommended"), is_active: bool(form, "is_active"),
    insights_level: str(form, "insights_level"), sort_order: num(form, "sort_order"),
  }).eq("id", str(form, "id"));
  done("/plans", error);
}
