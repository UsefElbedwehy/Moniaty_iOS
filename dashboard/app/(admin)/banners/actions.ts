"use server";
import { supabaseServer } from "@/lib/supabase/server";
import { done, str, optStr, bool, num, tr } from "@/lib/act";

/** `datetime-local` values are entered in Saudi time. */
const optTime = (form: FormData, key: string) => (str(form, key) ? new Date(`${str(form, key)}:00+03:00`).toISOString() : null);

export async function saveBanner(form: FormData) {
  const supabase = await supabaseServer();
  const id = optStr(form, "id");
  let imageUrl = optStr(form, "image_url");
  // Optional new image: uploaded to the public `content` bucket under a versioned path so apps
  // pick up the change without cache problems.
  const file = form.get("image_file");
  if (file instanceof File && file.size > 0) {
    if (file.size > 1024 * 1024) return done("/banners", { message: await tr("حجم الصورة أكبر من ١ ميغابايت", "The image is larger than 1 MB") });
    const ext = file.type === "image/jpeg" ? "jpg" : file.type === "image/png" ? "png" : file.type === "image/webp" ? "webp" : null;
    if (!ext) return done("/banners", { message: await tr("الصورة يجب أن تكون JPG أو PNG أو WebP", "The image must be JPG, PNG or WebP") });
    const path = `banners/${Date.now()}.${ext}`;
    const { error: uploadError } = await supabase.storage.from("content").upload(path, file, { contentType: file.type, upsert: false });
    if (uploadError) return done("/banners", uploadError);
    imageUrl = supabase.storage.from("content").getPublicUrl(path).data.publicUrl;
  }
  const link = optStr(form, "link_url");
  if (link && !/^(https:\/\/|munyati:\/\/)/.test(link)) {
    return done("/banners", { message: await tr("الرابط يجب أن يبدأ بـ https://", "The link must start with https://") });
  }
  const cities = form.getAll("city_ids").map(String).filter(Boolean);
  const row = {
    title_ar: str(form, "title_ar"), title_en: str(form, "title_en"),
    subtitle_ar: optStr(form, "subtitle_ar"), subtitle_en: optStr(form, "subtitle_en"),
    cta_ar: optStr(form, "cta_ar"), cta_en: optStr(form, "cta_en"),
    image_url: imageUrl, link_url: link, city_ids: cities.length ? cities : null,
    starts_at: optTime(form, "starts_at"), ends_at: optTime(form, "ends_at"),
    is_active: bool(form, "is_active"), sort_order: num(form, "sort_order"),
  };
  const { error } = id
    ? await supabase.from("home_banners").update(row).eq("id", id)
    : await supabase.from("home_banners").insert(row);
  return done("/banners", error);
}

export async function deleteBanner(form: FormData) {
  const supabase = await supabaseServer();
  const { error } = await supabase.from("home_banners").delete().eq("id", str(form, "id"));
  return done("/banners", error, ["تم الحذف", "Deleted"]);
}
