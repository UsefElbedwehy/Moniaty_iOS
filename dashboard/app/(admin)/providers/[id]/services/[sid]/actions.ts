"use server";
import { revalidatePath } from "next/cache";
import { supabaseServer } from "@/lib/supabase/server";
import { done, rpcError, str, tr } from "@/lib/act";

export type ServiceVideo = { url: string; poster_url: string | null; duration_seconds: number | null };

/** Same limits as the apps and the database. */
const MAX_PHOTOS = 30;
const MAX_VIDEOS = 3;
const CONTENT_PREFIX = "/storage/v1/object/public/content/";

async function current(serviceId: string) {
  const supabase = await supabaseServer();
  const { data, error } = await supabase.from("services").select("provider_id, image_urls, videos").eq("id", serviceId).maybeSingle();
  return { supabase, row: data as { provider_id: string; image_urls: string[]; videos: ServiceVideo[] } | null, error };
}

/** Called by the upload component after it put the files in `content/services/<id>/`. */
export async function addServiceMedia(serviceId: string, images: string[], videos: ServiceVideo[]): Promise<{ error?: string }> {
  const { supabase, row, error } = await current(serviceId);
  if (error || !row) return { error: error?.message ?? (await tr("الخدمة غير موجودة", "Service not found")) };
  const nextImages = [...(row.image_urls ?? []), ...images];
  const nextVideos = [...(row.videos ?? []), ...videos];
  if (nextImages.length > MAX_PHOTOS) return { error: await tr(`الحد الأقصى ${MAX_PHOTOS} صورة`, `At most ${MAX_PHOTOS} photos`) };
  if (nextVideos.length > MAX_VIDEOS) return { error: await tr(`الحد الأقصى ${MAX_VIDEOS} فيديوهات`, `At most ${MAX_VIDEOS} videos`) };
  const failed = rpcError(await supabase.rpc("admin_set_service_media", { p_service: serviceId, p_image_urls: nextImages, p_videos: nextVideos }));
  if (failed) return { error: failed.message };
  revalidatePath(`/providers/${row.provider_id}/services/${serviceId}`);
  return {};
}

/** Files the dashboard uploaded are deleted with the item; a provider's own uploads stay theirs. */
async function deleteIfOurs(supabase: Awaited<ReturnType<typeof supabaseServer>>, urls: (string | null | undefined)[]) {
  const paths = urls.filter((u): u is string => !!u && u.includes(CONTENT_PREFIX + "services/"))
    .map((u) => u.slice(u.indexOf(CONTENT_PREFIX) + CONTENT_PREFIX.length));
  if (paths.length) await supabase.storage.from("content").remove(paths);
}

export async function removeServicePhoto(form: FormData) {
  const serviceId = str(form, "service");
  const url = str(form, "url");
  const { supabase, row, error } = await current(serviceId);
  const back = `/providers/${row?.provider_id ?? ""}/services/${serviceId}`;
  if (error || !row) return done(back, error ?? { message: "not found" });
  const failed = rpcError(await supabase.rpc("admin_set_service_media", {
    p_service: serviceId, p_image_urls: row.image_urls.filter((u) => u !== url), p_videos: row.videos ?? [],
  }));
  if (!failed) await deleteIfOurs(supabase, [url]);
  return done(back, failed, ["تم حذف الصورة", "Photo removed"]);
}

export async function removeServiceVideo(form: FormData) {
  const serviceId = str(form, "service");
  const url = str(form, "url");
  const { supabase, row, error } = await current(serviceId);
  const back = `/providers/${row?.provider_id ?? ""}/services/${serviceId}`;
  if (error || !row) return done(back, error ?? { message: "not found" });
  const removed = (row.videos ?? []).find((v) => v.url === url);
  const failed = rpcError(await supabase.rpc("admin_set_service_media", {
    p_service: serviceId, p_image_urls: row.image_urls ?? [], p_videos: (row.videos ?? []).filter((v) => v.url !== url),
  }));
  if (!failed) await deleteIfOurs(supabase, [removed?.url, removed?.poster_url]);
  return done(back, failed, ["تم حذف الفيديو", "Video removed"]);
}
