"use server";
import { supabaseServer } from "@/lib/supabase/server";
import { done, str, optStr, bool, num, tr } from "@/lib/act";

const KINDS = ["wedding", "jalwa", "evening"];

/** A Saudi mobile in any common form (05…, 5…, 9665…, +9665…) → +9665XXXXXXXX; null if not one. */
function saudiMobile(text: string): string | null {
  let digits = text.replace(/[٠-٩]/g, (d) => String("٠١٢٣٤٥٦٧٨٩".indexOf(d))).replace(/\D/g, "");
  digits = digits.replace(/^(00)?966/, "").replace(/^0/, "");
  return /^5\d{8}$/.test(digits) ? `+966${digits}` : null;
}

/** Today in Saudi time, "yyyy-mm-dd". */
const today = () => new Date(Date.now() + 3 * 3600_000).toISOString().slice(0, 10);

export async function saveDress(form: FormData) {
  const supabase = await supabaseServer();
  const id = optStr(form, "id");
  const back = `/dresses?kind=${encodeURIComponent(str(form, "kind") || "wedding")}`;
  const kind = str(form, "kind");
  if (!KINDS.includes(kind)) return done(back, { message: await tr("اختاري القائمة", "Choose the list") });
  let imageUrl = optStr(form, "image_url");
  const file = form.get("image_file");
  if (file instanceof File && file.size > 0) {
    if (file.size > 3 * 1024 * 1024) return done(back, { message: await tr("حجم الصورة أكبر من ٣ ميغابايت", "The image is larger than 3 MB") });
    const ext = file.type === "image/jpeg" ? "jpg" : file.type === "image/png" ? "png" : file.type === "image/webp" ? "webp" : null;
    if (!ext) return done(back, { message: await tr("الصورة يجب أن تكون JPG أو PNG أو WebP", "The image must be JPG, PNG or WebP") });
    const path = `dresses/${Date.now()}.${ext}`;
    const { error: uploadError } = await supabase.storage.from("content").upload(path, file, { contentType: file.type, cacheControl: "31536000", upsert: false });
    if (uploadError) return done(back, uploadError);
    imageUrl = supabase.storage.from("content").getPublicUrl(path).data.publicUrl;
  }
  if (!imageUrl) return done(back, { message: await tr("أضيفي صورة الفستان", "Add the dress photo") });
  const price = num(form, "price");
  if (!(price >= 0) || !str(form, "price")) return done(back, { message: await tr("اكتبي السعر", "Enter the price") });
  const phone = saudiMobile(str(form, "contact_phone"));
  if (!phone) return done(back, { message: await tr("رقم التواصل يجب أن يكون جوالاً سعودياً، مثل 0551234567", "The contact number must be a Saudi mobile, e.g. 0551234567") });
  const row = {
    kind, image_url: imageUrl, price, contact_phone: phone,
    starts_on: str(form, "starts_on") || today(),
    is_active: bool(form, "is_active"),
  };
  const { error } = id
    ? await supabase.from("dress_listings").update(row).eq("id", id)
    : await supabase.from("dress_listings").insert(row);
  return done(back, error);
}

/** Another 30 days, from today. */
export async function renewDress(form: FormData) {
  const supabase = await supabaseServer();
  const { error } = await supabase.from("dress_listings").update({ starts_on: today(), is_active: true }).eq("id", str(form, "id"));
  return done(`/dresses?kind=${encodeURIComponent(str(form, "kind"))}`, error, ["تم التجديد لمدة ٣٠ يوماً", "Renewed for 30 days"]);
}

export async function deleteDress(form: FormData) {
  const supabase = await supabaseServer();
  const { error } = await supabase.from("dress_listings").delete().eq("id", str(form, "id"));
  return done(`/dresses?kind=${encodeURIComponent(str(form, "kind"))}`, error, ["تم الحذف", "Deleted"]);
}

/** The notice for dress owners: the price of a month's listing and Munyati's number. */
export async function saveDressNotice(form: FormData) {
  const supabase = await supabaseServer();
  const raw = str(form, "phone");
  const phone = raw ? saudiMobile(raw) : null;
  if (raw && !phone) return done("/dresses", { message: await tr("الرقم يجب أن يكون جوالاً سعودياً", "The number must be a Saudi mobile") });
  const { data } = await supabase.from("app_config").select("config").eq("id", 1).single();
  const config = (data?.config ?? {}) as Record<string, unknown>;
  const next = { ...config, dress_listing: { price: num(form, "price"), days: 30, phone } };
  const { error } = await supabase.from("app_config").update({ config: next }).eq("id", 1);
  return done("/dresses", error);
}
