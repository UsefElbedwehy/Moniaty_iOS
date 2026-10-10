import Link from "next/link";
import { notFound } from "next/navigation";
import { supabaseServer } from "@/lib/supabase/server";
import { Badge, Flash } from "@/components/ui";
import { ConfirmButton } from "@/components/ConfirmButton";
import { fmtDate, fmtDateTime, fmtSAR } from "@/lib/format";
import { bookingStatus, providerStatus } from "@/lib/labels";
import { grantSubscription, reviewProvider, setServiceStatus } from "../actions";

export default async function ProviderDetail({ params, searchParams }: {
  params: Promise<{ id: string }>; searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const { id } = await params;
  const sp = await searchParams;
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
    supabase.from("subscription_plans").select("id, name_ar").order("sort_order"),
    supabase.from("provider_payment_methods").select("kind, label, account_name, value, is_active").eq("provider_id", id),
  ]);
  const back = `/providers/${id}`;

  return (
    <>
      <div className="topbar">
        <div>
          <h1>{p.business_name || "بدون اسم"} {p.is_verified && <span className="badge brand">موثّقة</span>}</h1>
          <Badge map={providerStatus} value={p.status} />
        </div>
        <Link className="button secondary" href="/providers">رجوع</Link>
      </div>
      <Flash sp={sp} />

      <div className="grid two">
        <div className="card">
          <h2 style={{ marginTop: 0 }}>البيانات</h2>
          <dl className="kv">
            <dt>الجوال</dt><dd><span className="ltr">{profile.data?.phone ?? "—"}</span></dd>
            <dt>الاسم</dt><dd>{profile.data?.display_name ?? "—"}</dd>
            <dt>السجل التجاري</dt><dd className="mono">{p.cr_number ?? "—"}</dd>
            <dt>وثيقة العمل الحر</dt><dd className="mono">{p.freelance_doc_number ?? "—"}</dd>
            <dt>الأقسام</dt><dd>{(categories.data ?? []).map((c) => c.category_id).join("، ") || "—"}</dd>
            <dt>المدن</dt><dd>{(cities.data ?? []).map((c) => c.city_id).join("، ") || "—"}</dd>
            <dt>العنوان</dt><dd>{p.address ?? "—"}</dd>
            <dt>إنستغرام</dt><dd className="ltr">{p.instagram ?? "—"}</dd>
            <dt>طاقم نسائي فقط</dt><dd>{p.female_staff_only ? "نعم" : "لا"}</dd>
            <dt>نهاية التجربة</dt><dd>{fmtDate(p.trial_ends_at)}</dd>
            <dt>التقييم</dt><dd>{p.rating_avg ?? "—"} ({p.rating_count})</dd>
            <dt>تاريخ التسجيل</dt><dd>{fmtDate(p.created_at)}</dd>
            {p.review_note && (<><dt>ملاحظة المراجعة</dt><dd>{p.review_note}</dd></>)}
          </dl>
          {p.bio && <p className="muted">{p.bio}</p>}
        </div>

        <div className="card">
          <h2 style={{ marginTop: 0 }}>قرار الإدارة</h2>
          <form className="stack" action={reviewProvider}>
            <input type="hidden" name="id" value={id} />
            <label>الحالة
              <select name="status" defaultValue={p.status === "pending" ? "approved" : p.status}>
                <option value="approved">تفعيل</option>
                <option value="rejected">رفض</option>
                <option value="suspended">إيقاف</option>
                <option value="pending">إعادة للمراجعة</option>
              </select>
            </label>
            <label className="check"><input type="checkbox" name="verified" defaultChecked={p.is_verified} /> شارة «موثّقة» (تحققت من السجل أو الوثيقة)</label>
            <label>ملاحظة (تظهر لمقدّمة الخدمة عند الرفض أو الإيقاف)
              <textarea name="note" defaultValue={p.review_note ?? ""} />
            </label>
            <ConfirmButton message="حفظ القرار وإشعار مقدّمة الخدمة؟">حفظ القرار</ConfirmButton>
          </form>

          <h2>إضافة مدة مجانية</h2>
          <form className="inline" action={grantSubscription}>
            <input type="hidden" name="id" value={id} />
            <select name="plan">{(plans.data ?? []).map((pl) => <option key={pl.id} value={pl.id}>{pl.name_ar}</option>)}</select>
            <input name="months" type="number" min={1} max={12} defaultValue={1} style={{ width: 80 }} />
            <input name="note" placeholder="السبب" />
            <ConfirmButton message="إضافة مدة مجانية لهذه الباقة؟" className="secondary">إضافة</ConfirmButton>
          </form>
        </div>
      </div>

      <h2>الخدمات</h2>
      <div className="table-wrap">
        <table>
          <thead><tr><th></th><th>الخدمة</th><th>القسم</th><th>السعر</th><th>الحالة</th><th></th></tr></thead>
          <tbody>
            {(services.data ?? []).map((s) => (
              <tr key={s.id}>
                <td>{s.image_urls?.[0] && <img className="thumb" src={s.image_urls[0]} alt="" />}</td>
                <td>{s.title}</td>
                <td>{s.category_id}</td>
                <td>{fmtSAR(s.price)}</td>
                <td>{s.status === "active" ? <span className="badge good">نشطة</span> : <span className="badge">موقوفة</span>}</td>
                <td>
                  <form className="inline" action={setServiceStatus}>
                    <input type="hidden" name="service" value={s.id} />
                    <input type="hidden" name="back" value={back} />
                    <input type="hidden" name="status" value={s.status === "active" ? "paused" : "active"} />
                    {s.status === "active" && <input name="note" placeholder="سبب الإيقاف" />}
                    <ConfirmButton message="تأكيد؟" className={s.status === "active" ? "danger" : "secondary"}>
                      {s.status === "active" ? "إيقاف" : "تفعيل"}
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
          <h2 style={{ marginTop: 0 }}>الاشتراك</h2>
          {(periods.data ?? []).length === 0 ? <p className="muted">لا توجد فترات مدفوعة.</p> : (
            <table><tbody>{(periods.data ?? []).map((s, i) => (
              <tr key={i}><td>{s.plan_id}</td><td>{s.source}</td><td>{s.status}</td><td>{fmtDate(s.starts_at)} ← {fmtDate(s.ends_at)}</td></tr>
            ))}</tbody></table>
          )}
          <h2>طرق استلام المبالغ</h2>
          {(methods.data ?? []).map((m, i) => (
            <div key={i} className="small">{m.label} · {m.account_name} · <span className="ltr mono">{m.value}</span> {!m.is_active && "(مخفية)"}</div>
          ))}
          <h2>المتاجر</h2>
          {(stores.data ?? []).map((st) => <div key={st.id}>{st.name} {!st.is_active && <span className="badge">مخفي</span>}</div>)}
        </div>
        <div className="card">
          <h2 style={{ marginTop: 0 }}>آخر الحجوزات</h2>
          {(bookings.data ?? []).map((b) => (
            <div key={b.id} style={{ display: "flex", justifyContent: "space-between", marginBottom: 6 }}>
              <Link href={`/bookings/${b.id}`} className="mono">{b.reference_code}{b.is_demo && " (تجريبي)"}</Link>
              <span>{fmtDateTime(b.starts_at)}</span>
              <Badge map={bookingStatus} value={b.status} />
            </div>
          ))}
        </div>
      </div>
    </>
  );
}
