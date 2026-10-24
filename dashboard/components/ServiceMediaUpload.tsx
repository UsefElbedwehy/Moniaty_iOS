"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { supabaseBrowser } from "@/lib/supabase/client";
import type { Lang } from "@/lib/i18n";
import { addServiceMedia, type ServiceVideo } from "@/app/(admin)/providers/[id]/services/[sid]/actions";

/** Same limits as the apps: 60-second videos, at most 50 MB (the storage upload limit). */
const MAX_SECONDS = 60;
const MAX_VIDEO_BYTES = 50 * 1024 * 1024;
/** Picked photos can be large camera files; they are shrunk in the browser before upload. */
const MAX_PHOTO_BYTES = 20 * 1024 * 1024;
const PHOTO_TYPES: Record<string, string> = { "image/jpeg": "jpg", "image/png": "png", "image/webp": "webp" };

/**
 * Uploads photos and MP4 videos for a service straight from the browser to the public `content`
 * bucket (`services/<id>/…`), so large videos never pass through a server action, then saves the
 * URLs. For each video it reads the length and grabs a poster frame, like the apps do.
 */
export function ServiceMediaUpload({ serviceId, lang, photosLeft, videosLeft }: {
  serviceId: string; lang: Lang; photosLeft: number; videosLeft: number;
}) {
  const t = (ar: string, en: string) => (lang === "ar" ? ar : en);
  const router = useRouter();
  const [busy, setBusy] = useState("");
  const [error, setError] = useState("");

  async function upload(files: FileList | null) {
    if (!files?.length) return;
    setError("");
    const supabase = supabaseBrowser();
    const images: string[] = [];
    const videos: ServiceVideo[] = [];
    const put = async (blob: Blob, ext: string, type: string) => {
      const path = `services/${serviceId}/${Date.now()}-${Math.random().toString(36).slice(2, 8)}.${ext}`;
      const { error: e } = await supabase.storage.from("content")
        .upload(path, blob, { contentType: type, cacheControl: "31536000", upsert: false });
      if (e) throw new Error(e.message);
      return supabase.storage.from("content").getPublicUrl(path).data.publicUrl;
    };
    try {
      for (const file of Array.from(files)) {
        if (PHOTO_TYPES[file.type]) {
          if (images.length >= photosLeft) throw new Error(t("وصلت الخدمة إلى الحد الأقصى للصور", "The service has reached its photo limit"));
          if (file.size > MAX_PHOTO_BYTES) throw new Error(t(`${file.name}: الصورة أكبر من ٢٠ ميغابايت`, `${file.name}: the photo is larger than 20 MB`));
          setBusy(t(`جارٍ تجهيز ${file.name}…`, `Preparing ${file.name}…`));
          const photo = await shrinkPhoto(file);
          setBusy(t(`جارٍ رفع ${file.name}…`, `Uploading ${file.name}…`));
          images.push(photo ? await put(photo, "jpg", "image/jpeg") : await put(file, PHOTO_TYPES[file.type], file.type));
        } else if (file.type === "video/mp4") {
          if (videos.length >= videosLeft) throw new Error(t("وصلت الخدمة إلى الحد الأقصى للفيديوهات (٣)", "The service has reached its video limit (3)"));
          if (file.size > MAX_VIDEO_BYTES) throw new Error(t(`${file.name}: الفيديو أكبر من ٥٠ ميغابايت`, `${file.name}: the video is larger than 50 MB`));
          setBusy(t(`جارٍ تجهيز ${file.name}…`, `Preparing ${file.name}…`));
          const { duration, poster } = await inspectVideo(file);
          if (duration > MAX_SECONDS + 0.9) throw new Error(t(`${file.name}: مدة الفيديو أطول من ${MAX_SECONDS} ثانية`, `${file.name}: the video is longer than ${MAX_SECONDS} seconds`));
          setBusy(t(`جارٍ رفع ${file.name}…`, `Uploading ${file.name}…`));
          const url = await put(file, "mp4", "video/mp4");
          const posterUrl = poster ? await put(poster, "jpg", "image/jpeg") : null;
          videos.push({ url, poster_url: posterUrl, duration_seconds: Math.round(duration) });
        } else {
          throw new Error(t(`${file.name}: الصيغ المقبولة JPG أو PNG أو WebP للصور، وMP4 للفيديو`, `${file.name}: use JPG, PNG or WebP for photos and MP4 for video`));
        }
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    }
    if (images.length || videos.length) {
      setBusy(t("جارٍ الحفظ…", "Saving…"));
      const result = await addServiceMedia(serviceId, images, videos);
      if (result.error) setError(result.error);
      router.refresh();
    }
    setBusy("");
  }

  return (
    <div style={{ display: "grid", gap: 8 }}>
      <label className="button secondary" style={{ alignSelf: "flex-start", cursor: busy ? "wait" : "pointer" }}>
        {busy || t("إضافة صور أو فيديو", "Add photos or video")}
        <input type="file" multiple hidden disabled={!!busy} accept="image/jpeg,image/png,image/webp,video/mp4"
          onChange={(e) => { void upload(e.target.files); e.target.value = ""; }} />
      </label>
      <p className="muted small">
        {t(`الصور: JPG أو PNG أو WebP حتى ٢٠ ميغابايت، وتُصغَّر تلقائياً قبل الرفع. الفيديو: MP4 حتى ${MAX_SECONDS} ثانية و٥٠ ميغابايت (يتبقّى ${videosLeft}).`,
           `Photos: JPG, PNG or WebP up to 20 MB, shrunk automatically before upload. Video: MP4 up to ${MAX_SECONDS} seconds and 50 MB (${videosLeft} left).`)}
      </p>
      {error && <p className="flash err">{error}</p>}
    </div>
  );
}

/**
 * The photo as the apps upload it: longest side at most 1600 px, JPEG at quality 0.8 (usually a few
 * hundred KB). Returns null to upload the original instead, when it is already smaller or the
 * browser can't decode it.
 */
async function shrinkPhoto(file: File): Promise<Blob | null> {
  try {
    const bitmap = await createImageBitmap(file, { imageOrientation: "from-image" });
    const scale = Math.min(1, 1600 / Math.max(bitmap.width, bitmap.height));
    const canvas = document.createElement("canvas");
    canvas.width = Math.round(bitmap.width * scale);
    canvas.height = Math.round(bitmap.height * scale);
    const ctx = canvas.getContext("2d");
    if (!ctx || !canvas.width) return null;
    ctx.fillStyle = "#fff";   // transparent PNG areas become white, not black
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.imageSmoothingQuality = "high";
    ctx.drawImage(bitmap, 0, 0, canvas.width, canvas.height);
    bitmap.close();
    const blob = await new Promise<Blob | null>((resolve) => canvas.toBlob(resolve, "image/jpeg", 0.8));
    return blob && (scale < 1 || blob.size < file.size) ? blob : null;
  } catch {
    return null;
  }
}

/** The video's length, and a JPEG of the frame about a second in (longest side ≤ 1280 px). */
function inspectVideo(file: File): Promise<{ duration: number; poster: Blob | null }> {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file);
    const video = document.createElement("video");
    video.muted = true;
    video.playsInline = true;
    video.preload = "auto";
    const finish = (poster: Blob | null) => { URL.revokeObjectURL(url); resolve({ duration: video.duration, poster }); };
    video.onerror = () => { URL.revokeObjectURL(url); reject(new Error(`${file.name}: this browser can't read the video (use MP4 / H.264)`)); };
    video.onloadedmetadata = () => { video.currentTime = Math.min(1, video.duration / 2); };
    video.onseeked = () => {
      const scale = Math.min(1, 1280 / Math.max(video.videoWidth, video.videoHeight));
      const canvas = document.createElement("canvas");
      canvas.width = Math.round(video.videoWidth * scale);
      canvas.height = Math.round(video.videoHeight * scale);
      const ctx = canvas.getContext("2d");
      if (!ctx || !canvas.width) return finish(null);
      ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
      canvas.toBlob((blob) => finish(blob), "image/jpeg", 0.8);
    };
    video.src = url;
  });
}
