import Link from "next/link";
import { notFound } from "next/navigation";
import { supabaseServer } from "@/lib/supabase/server";
import { Badge, Flash } from "@/components/ui";
import { ConfirmButton } from "@/components/ConfirmButton";
import { i18n } from "@/lib/i18n";
import { bookingStatus, providerStatus } from "@/lib/labels";
import { grantSubscription, reviewProvider, setServiceStatus } from "../actions";

export default async function ProviderDetail({ params, searchParams }: {
  params: Promise<{ id: string }>; searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const { id } = await params;
  const sp = await searchParams;
  const { t, lang, list, arrow, date: fmtDate, dateTime: fmtDateTime, sar: fmtSAR } = await i18n();
  const supabase = await supabaseServer();
  const { data: p } = await supabase.from("providers").select("*").eq("id", id).maybeSingle();
  if (!p) notFound();
  const [profile, categories, cities, services, stores, periods, bookings, plans, methods] = await Promise.all([
    supabase.from("profiles").select("phone, display_name, created_at, is_banned, deleted_at").eq("id", id).maybeSingle(),
    supabase.from("provider_categories").select("category_id").eq("provider_id", id),
    supabase.from("provider_cities").select("city_id").eq("provider_id", id),
    supabase.from("services").select("id, title, price, status, category_id, image_urls, created_at").eq("provider_id", id).order("created_at"),
    supabase.from("stores").select("id, name, is_active, address").eq("provider_id", id),
    supabase.from("provider_subscriptions").select("plan_id, source, status, starts_at, ends_at, note").eq("provider_id", id).order("starts_at", { ascending: false }).limit(10),
    supabase.from("bookings").select("id, reference_code, status, price, starts_at, is_demo").eq("provider_id", id).order("created_at", { ascending: false }).limit(10),
    supabase.from("subscription_plans").select("id, name_ar, name_en").order("sort_order"),
    supabase.from("provider_payment_methods").select("kind, label, account_name, value, is_active").eq("provider_id", id),
  ]);
  const back = `/providers/${id}`;

  return (
    <>
      <div className="topbar">
        <div>
          <h1>{p.business_name || t("بدون اسم", "Unnamed")} {p.is_verified && <span className="badge brand">{t("موثّقة", "Verified")}</span>}</h1>
          <Badge map={providerStatus} value={p.status} />
        </div>
        <Link className="button secondary" href="/providers">{t("رجوع", "Back")}</Link>
      </div>
      <Flash sp={sp} />

      <div className="grid two">
        <div className="card">
          <h2 style={{ marginTop: 0 }}>{t("البيانات", "Details")}</h2>
          <dl className="kv">
            <dt>{t("الجوال", "Mobile")}</dt><dd><span className="ltr">{profile.data?.phone ?? "—"}</span></dd>
            <dt>{t("الاسم", "Name")}</dt><dd>{profile.data?.display_name ?? "—"}</dd>
            <dt>{t("السجل التجاري", "Commercial registration")}</dt><dd className="mono">{p.cr_number ?? "—"}</dd>
            <dt>{t("وثيقة العمل الحر", "Freelance certificate")}</dt><dd className="mono">{p.freelance_doc_number ?? "—"}</dd>
            <dt>{t("الأقسام", "Categories")}</dt><dd>{list((categories.data ?? []).map((c) => c.category_id)) || "—"}</dd>
            <dt>{t("المدن", "Cities")}</dt><dd>{list((cities.data ?? []).map((c) => c.city_id)) || "—"}</dd>
            <dt>{t("العنوان", "Address")}</dt><dd>{p.address ?? "—"}</dd>
            <dt>{t("إنستغرام", "Instagram")}</dt><dd className="ltr">{p.instagram ?? "—"}</dd>
            <dt>{t("طاقم نسائي فقط", "Female staff only")}</dt><dd>{p.female_staff_only ? t("نعم", "Yes") : t("لا", "No")}</dd>
            <dt>{t("نهاية التجربة", "Trial ends")}</dt><dd>{fmtDate(p.trial_ends_at)}</dd>
            <dt>{t("التقييم", "Rating")}</dt><dd>{p.rating_avg ?? "—"} ({p.rating_count})</dd>
            <dt>{t("تاريخ التسجيل", "Joined")}</dt><dd>{fmtDate(p.created_at)}</dd>
            {p.review_note && (<><dt>{t("ملاحظة المراجعة", "Review note")}</dt><dd>{p.review_note}</dd></>)}
          </dl>
          {p.bio && <p className="muted">{p.bio}</p>}
        </div>

        <div className="card">
          <h2 style={{ marginTop: 0 }}>{t("قرار الإدارة", "Admin decision")}</h2>
          <form className="stack" action={reviewProvider}>
            <input type="hidden" name="id" value={id} />
            <label>{t("الحالة", "Status")}
              <select name="status" defaultValue={p.status === "pending" ? "approved" : p.status}>
                <option value="approved">{t("تفعيل", "Approve")}</option>
                <option value="rejected">{t("رفض", "Reject")}</option>
                <option value="suspended">{t("إيقاف", "Suspend")}</option>
                <option value="pending">{t("إعادة للمراجعة", "Back to review")}</option>
              </select>
            </label>
            <label className="check"><input type="checkbox" name="verified" defaultChecked={p.is_verified} /> {t("شارة «موثّقة» (تحققت من السجل أو الوثيقة)", "“Verified” badge (CR or certificate checked)")}</label>
            <label>{t("ملاحظة (تظهر لمقدّمة الخدمة عند الرفض أو الإيقاف)", "Note (shown to the provider when rejected or suspended)")}
              <textarea name="note" defaultValue={p.review_note ?? ""} />
            </label>
            <ConfirmButton message={t("حفظ القرار وإشعار مقدّمة الخدمة؟", "Save the decision and notify the provider?")}>{t("حفظ القرار", "Save decision")}</ConfirmButton>
          </form>

          <h2>{t("إضافة مدة مجانية", "Grant free time")}</h2>
          <form className="inline" action={grantSubscription}>
            <input type="hidden" name="id" value={id} />
            <select name="plan">{(plans.data ?? []).map((pl) => <option key={pl.id} value={pl.id}>{lang === "ar" ? pl.name_ar : pl.name_en}</option>)}</select>
            <input name="months" type="number" min={1} max={12} defaultValue={1} style={{ width: 80 }} />
            <input name="note" placeholder={t("السبب", "Reason")} />
            <ConfirmButton message={t("إضافة مدة مجانية لهذه الباقة؟", "Grant free time on this plan?")} className="secondary">{t("إضافة", "Grant")}</ConfirmButton>
          </form>
        </div>
      </div>

      <h2>{t("الخدمات", "Services")}</h2>
      <div className="table-wrap">
        <table>
          <thead><tr><th></th><th>{t("الخدمة", "Service")}</th><th>{t("القسم", "Category")}</th><th>{t("السعر", "Price")}</th><th>{t("الحالة", "Status")}</th><th></th></tr></thead>
          <tbody>
            {(services.data ?? []).map((s) => (
              <tr key={s.id}>
                <td>{s.image_urls?.[0] && <img className="thumb" src={s.image_urls[0]} alt="" />}</td>
                <td>{s.title}</td>
                <td>{s.category_id}</td>
                <td>{fmtSAR(s.price)}</td>
                <td>{s.status === "active" ? <span className="badge good">{t("نشطة", "Active")}</span> : <span className="badge">{t("موقوفة", "Paused")}</span>}</td>
                <td>
                  <form className="inline" action={setServiceStatus}>
                    <input type="hidden" name="service" value={s.id} />
                    <input type="hidden" name="back" value={back} />
                    <input type="hidden" name="status" value={s.status === "active" ? "paused" : "active"} />
                    {s.status === "active" && <input name="note" placeholder={t("سبب الإيقاف", "Reason for pausing")} />}
                    <ConfirmButton message={t("تأكيد؟", "Are you sure?")} className={s.status === "active" ? "danger" : "secondary"}>
                      {s.status === "active" ? t("إيقاف", "Pause") : t("تفعيل", "Activate")}
                    </ConfirmButton>
                  </form>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <div className="grid two" style={{ marginTop: 16 }}>
        <div className="card">
          <h2 style={{ marginTop: 0 }}>{t("الاشتراك", "Subscription")}</h2>
          {(periods.data ?? []).length === 0 ? <p className="muted">{t("لا توجد فترات مدفوعة.", "No paid periods.")}</p> : (
            <table><tbody>{(periods.data ?? []).map((s, i) => (
              <tr key={i}><td>{s.plan_id}</td><td>{s.source}</td><td>{s.status}</td><td>{fmtDate(s.starts_at)} {arrow} {fmtDate(s.ends_at)}</td></tr>
            ))}</tbody></table>
          )}
          <h2>{t("طرق استلام المبالغ", "Payout methods")}</h2>
          {(methods.data ?? []).map((m, i) => (
            <div key={i} className="small">{m.label} · {m.account_name} · <span className="ltr mono">{m.value}</span> {!m.is_active && t("(مخفية)", "(hidden)")}</div>
          ))}
          <h2>{t("المتاجر", "Stores")}</h2>
          {(stores.data ?? []).map((st) => <div key={st.id}>{st.name} {!st.is_active && <span className="badge">{t("مخفي", "Hidden")}</span>}</div>)}
        </div>
        <div className="card">
          <h2 style={{ marginTop: 0 }}>{t("آخر الحجوزات", "Recent bookings")}</h2>
          {(bookings.data ?? []).map((b) => (
            <div key={b.id} style={{ display: "flex", justifyContent: "space-between", marginBottom: 6 }}>
              <Link href={`/bookings/${b.id}`} className="mono">{b.reference_code}{b.is_demo && ` ${t("(تجريبي)", "(demo)")}`}</Link>
              <span>{fmtDateTime(b.starts_at)}</span>
              <Badge map={bookingStatus} value={b.status} />
            </div>
          ))}
        </div>
      </div>
    </>
  );
}
