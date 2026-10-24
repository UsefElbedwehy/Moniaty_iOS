// Record types the dashboard can edit, archive (restorable) and delete permanently (owner only).
// Keep in step with `admin_entity()` / `admin_update_record()` in
// supabase/migrations/20261021000000_admin_records.sql: only the fields listed here are editable.

export type Entity =
  | "user" | "provider" | "service" | "store" | "booking" | "review"
  | "report" | "ticket" | "banner" | "category" | "city" | "plan";

export type Field = {
  name: string;
  label: [ar: string, en: string];
  type: "text" | "textarea" | "number" | "bool" | "select";
  options?: [value: string, ar: string, en: string][];
};

type Config = {
  label: [ar: string, en: string];
  table: string;
  /** Column used as the record's name in lists (or a function of the row). */
  title: (row: Record<string, unknown>) => string;
  /** Where the record is managed normally. */
  href: (row: Record<string, unknown>) => string;
  fields?: Field[];
  /** Columns the edit page loads. */
  select: string;
};

const s = (v: unknown) => (v == null || v === "" ? "—" : String(v));

export const ENTITIES: Record<Entity, Config> = {
  user: {
    label: ["مستخدم", "User"], table: "profiles", select: "id, display_name, first_name, last_name, phone, role, created_at",
    title: (r) => s(r.display_name), href: (r) => (r.role === "provider" ? `/providers/${r.id}` : `/users?q=${r.id}`),
    fields: [
      { name: "first_name", label: ["الاسم الأول", "First name"], type: "text" },
      { name: "last_name", label: ["اسم العائلة", "Last name"], type: "text" },
    ],
  },
  provider: {
    label: ["مقدّمة خدمة", "Provider"], table: "providers",
    select: "id, business_name, bio, address, instagram, cr_number, freelance_doc_number, female_staff_only, is_verified, review_note, status",
    title: (r) => s(r.business_name), href: (r) => `/providers/${r.id}`,
    fields: [
      { name: "business_name", label: ["اسم النشاط", "Business name"], type: "text" },
      { name: "bio", label: ["النبذة", "Bio"], type: "textarea" },
      { name: "address", label: ["العنوان", "Address"], type: "text" },
      { name: "instagram", label: ["إنستغرام", "Instagram"], type: "text" },
      { name: "cr_number", label: ["السجل التجاري", "Commercial registration"], type: "text" },
      { name: "freelance_doc_number", label: ["وثيقة العمل الحر", "Freelance certificate"], type: "text" },
      { name: "female_staff_only", label: ["طاقم نسائي فقط", "Female staff only"], type: "bool" },
      { name: "is_verified", label: ["شارة «موثّقة»", "“Verified” badge"], type: "bool" },
      { name: "review_note", label: ["ملاحظة الإدارة", "Admin note"], type: "textarea" },
    ],
  },
  service: {
    label: ["خدمة", "Service"], table: "services",
    select: "id, provider_id, title, description, price, duration_minutes, category_id, female_staff_only, at_customer_location, status",
    title: (r) => s(r.title), href: (r) => `/providers/${r.provider_id}/services/${r.id}`,
    fields: [
      { name: "title", label: ["اسم الخدمة", "Title"], type: "text" },
      { name: "description", label: ["الوصف", "Description"], type: "textarea" },
      { name: "price", label: ["السعر (ر.س)", "Price (SAR)"], type: "number" },
      { name: "duration_minutes", label: ["المدة (دقيقة)", "Duration (minutes)"], type: "number" },
      { name: "category_id", label: ["القسم (المعرّف)", "Category (id)"], type: "text" },
      { name: "female_staff_only", label: ["طاقم نسائي فقط", "Female staff only"], type: "bool" },
      { name: "at_customer_location", label: ["في موقع العروس", "At the bride’s location"], type: "bool" },
      { name: "status", label: ["الحالة", "Status"], type: "select", options: [["active", "نشطة", "Active"], ["paused", "موقوفة", "Paused"]] },
    ],
  },
  store: {
    label: ["متجر", "Store"], table: "stores", select: "id, provider_id, name, description, address, instagram, is_active",
    title: (r) => s(r.name), href: (r) => `/providers/${r.provider_id}`,
    fields: [
      { name: "name", label: ["الاسم", "Name"], type: "text" },
      { name: "description", label: ["الوصف", "Description"], type: "textarea" },
      { name: "address", label: ["العنوان", "Address"], type: "text" },
      { name: "instagram", label: ["إنستغرام", "Instagram"], type: "text" },
      { name: "is_active", label: ["ظاهر", "Visible"], type: "bool" },
    ],
  },
  booking: {
    label: ["حجز", "Booking"], table: "bookings", select: "id, reference_code, note, status",
    title: (r) => s(r.reference_code), href: (r) => `/bookings/${r.id}`,
    fields: [
      { name: "note", label: ["ملاحظة العروس", "Bride’s note"], type: "textarea" },
      { name: "status", label: ["الحالة (تغيير يدوي بلا إشعارات)", "Status (manual override, no notifications)"], type: "select", options: [
        ["requested", "بانتظار الموافقة", "Requested"], ["reschedule_proposed", "موعد بديل مقترح", "New time proposed"],
        ["awaiting_payment", "بانتظار الدفع", "Awaiting payment"], ["payment_submitted", "إيصال مرفوع", "Receipt submitted"],
        ["payment_confirmed", "مؤكد", "Confirmed"], ["completed", "مكتمل", "Completed"], ["declined", "مرفوض", "Declined"],
        ["cancelled_by_bride", "ألغته العروس", "Cancelled by bride"], ["cancelled_by_provider", "ألغته مقدّمة الخدمة", "Cancelled by provider"],
        ["expired", "منتهي", "Expired"], ["disputed", "نزاع", "Disputed"]] },
    ],
  },
  review: { label: ["تقييم", "Review"], table: "reviews", select: "id, body, rating, status", title: (r) => `${r.rating ?? ""}★ ${s(r.body).slice(0, 40)}`, href: () => "/reviews" },
  report: {
    label: ["بلاغ", "Report"], table: "reports", select: "id, target_type, reason, status", title: (r) => `${s(r.target_type)} · ${s(r.reason)}`, href: () => "/reports",
    fields: [{ name: "status", label: ["الحالة", "Status"], type: "select", options: [["open", "مفتوح", "Open"], ["actioned", "تم الإجراء", "Actioned"], ["dismissed", "مرفوض", "Dismissed"]] }],
  },
  ticket: {
    label: ["طلب دعم", "Support ticket"], table: "support_tickets", select: "id, subject, status", title: (r) => s(r.subject), href: () => "/support",
    fields: [{ name: "status", label: ["الحالة", "Status"], type: "select", options: [["open", "مفتوح", "Open"], ["answered", "تم الرد", "Answered"], ["closed", "مغلق", "Closed"]] }],
  },
  banner: { label: ["بنر", "Banner"], table: "home_banners", select: "id, title_ar, title_en", title: (r) => s(r.title_ar) || "🖼", href: () => "/banners" },
  category: { label: ["قسم", "Category"], table: "categories", select: "id, name_ar, name_en", title: (r) => s(r.name_ar), href: () => "/catalog" },
  city: { label: ["مدينة", "City"], table: "cities", select: "id, name_ar, name_en", title: (r) => s(r.name_ar), href: () => "/catalog" },
  plan: { label: ["باقة", "Plan"], table: "subscription_plans", select: "id, name_ar, name_en", title: (r) => s(r.name_ar), href: () => "/plans" },
};

export const isEntity = (v: string): v is Entity => v in ENTITIES;

/** Typed confirmation for permanent deletes (either language). */
export const DELETE_WORDS = ["حذف", "DELETE", "delete"];
