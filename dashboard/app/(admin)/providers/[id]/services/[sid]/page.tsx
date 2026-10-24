import Link from "next/link";
import { notFound } from "next/navigation";
import { supabaseServer } from "@/lib/supabase/server";
import { Flash } from "@/components/ui";
import { ConfirmButton } from "@/components/ConfirmButton";
import { ServiceMediaUpload } from "@/components/ServiceMediaUpload";
import { i18n } from "@/lib/i18n";
import { thumbUrl } from "@/lib/format";
import { removeServicePhoto, removeServiceVideo, type ServiceVideo } from "./actions";

/** A service's photos and videos: watch them, remove anything inappropriate, or add media. */
export default async function ServiceMedia({ params, searchParams }: {
  params: Promise<{ id: string; sid: string }>; searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const { id, sid } = await params;
  const sp = await searchParams;
  const { t, lang, sar } = await i18n();
  const supabase = await supabaseServer();
  const { data: s } = await supabase.from("services")
    .select("id, provider_id, title, price, status, image_urls, videos").eq("id", sid).eq("provider_id", id).maybeSingle();
  if (!s) notFound();
  const photos: string[] = s.image_urls ?? [];
  const videos: ServiceVideo[] = s.videos ?? [];

  return (
    <>
      <div className="topbar">
        <div>
          <h1>{s.title}</h1>
          <span className="muted">{sar(s.price)} · {t("الصور والفيديوهات", "Photos and videos")}</span>
        </div>
        <Link className="button secondary" href={`/providers/${id}`}>{t("رجوع", "Back")}</Link>
      </div>
      <Flash sp={sp} />

      <div className="card" style={{ marginBottom: 16 }}>
        <ServiceMediaUpload serviceId={sid} lang={lang} photosLeft={Math.max(0, 30 - photos.length)} videosLeft={Math.max(0, 3 - videos.length)} />
      </div>

      <h2>{t("الفيديوهات", "Videos")} ({videos.length})</h2>
      {videos.length === 0 ? <p className="muted">{t("لا توجد فيديوهات.", "No videos.")}</p> : (
        <div className="media-grid">
          {videos.map((v) => (
            <figure key={v.url}>
              <video src={v.url} poster={v.poster_url ?? undefined} controls preload="none" playsInline />
              <figcaption>
                <span className="muted small ltr">{v.duration_seconds != null ? `${Math.floor(v.duration_seconds / 60)}:${String(v.duration_seconds % 60).padStart(2, "0")}` : ""}</span>
                <form className="inline" action={removeServiceVideo}>
                  <input type="hidden" name="service" value={sid} />
                  <input type="hidden" name="url" value={v.url} />
                  <ConfirmButton className="danger" message={t("حذف هذا الفيديو من الخدمة؟", "Remove this video from the service?")}>{t("حذف", "Remove")}</ConfirmButton>
                </form>
              </figcaption>
            </figure>
          ))}
        </div>
      )}

      <h2>{t("الصور", "Photos")} ({photos.length})</h2>
      {photos.length === 0 ? <p className="muted">{t("لا توجد صور.", "No photos.")}</p> : (
        <div className="media-grid">
          {photos.map((url, i) => (
            <figure key={url}>
              <a href={url} target="_blank" rel="noreferrer"><img src={thumbUrl(url)} alt="" loading="lazy" /></a>
              <figcaption>
                <span className="muted small">{i === 0 ? t("صورة الغلاف", "Cover photo") : ""}</span>
                <form className="inline" action={removeServicePhoto}>
                  <input type="hidden" name="service" value={sid} />
                  <input type="hidden" name="url" value={url} />
                  <ConfirmButton className="danger" message={t("حذف هذه الصورة من الخدمة؟", "Remove this photo from the service?")}>{t("حذف", "Remove")}</ConfirmButton>
                </form>
              </figcaption>
            </figure>
          ))}
        </div>
      )}
    </>
  );
}
