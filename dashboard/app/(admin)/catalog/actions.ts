"use server";
import { supabaseServer } from "@/lib/supabase/server";
import { done, str, optStr, bool, num } from "@/lib/act";

const slug = (v: string) => v.toLowerCase().replace(/[^a-z0-9_]/g, "_");
const optNum = (form: FormData, key: string) => (str(form, key) ? Number(str(form, key)) : null);

export async function saveCity(form: FormData) {
  const supabase = await supabaseServer();
  const { error } = await supabase.from("cities").upsert({
    id: slug(str(form, "id")), name_ar: str(form, "name_ar"), name_en: str(form, "name_en"),
    lat: optNum(form, "lat"), lng: optNum(form, "lng"), is_active: bool(form, "is_active"), sort_order: num(form, "sort_order"),
  });
  done("/catalog", error);
}

export async function saveCategory(form: FormData) {
  const supabase = await supabaseServer();
  const id = slug(str(form, "id"));
  let iconUrl = optStr(form, "icon_url");
  // Optional new icon: uploaded to the public `content` bucket under a versioned path so apps
  // pick up the change without cache problems.
  const file = form.get("icon_file");
  if (file instanceof File && file.size > 0) {
    if (file.size > 512 * 1024) done("/catalog", { message: "حجم الأيقونة أكبر من ٥١٢ كيلوبايت" });
    const ext = file.type === "image/svg+xml" ? "svg" : file.type === "image/png" ? "png" : null;
    if (!ext) done("/catalog", { message: "الأيقونة يجب أن تكون PNG أو SVG" });
    const path = `categories/${id}/${Date.now()}.${ext}`;
    const { error: uploadError } = await supabase.storage.from("content").upload(path, file, { contentType: file.type, upsert: false });
    if (uploadError) done("/catalog", uploadError);
    iconUrl = supabase.storage.from("content").getPublicUrl(path).data.publicUrl;
  }
  const { error } = await supabase.from("categories").upsert({
    id, name_ar: str(form, "name_ar"), name_en: str(form, "name_en"), icon_symbol: optStr(form, "icon_symbol"),
    icon_url: iconUrl, price_hint_ar: optStr(form, "price_hint_ar"), price_hint_en: optStr(form, "price_hint_en"),
    is_active: bool(form, "is_active"), sort_order: num(form, "sort_order"),
    allows_parallel_bookings: bool(form, "allows_parallel_bookings"), is_store_category: bool(form, "is_store_category"),
  });
  done("/catalog", error);
}
