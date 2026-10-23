// Status maps are [Arabic, English, badge tone]; reason maps are [Arabic, English].
// Render them with <Badge> or `label()` from i18n().

export type StatusMap = Record<string, readonly [ar: string, en: string, tone: string]>;
export type LabelMap = Record<string, readonly [ar: string, en: string]>;

export const providerStatus: StatusMap = {
  pending: ["قيد المراجعة", "Pending review", "warn"],
  approved: ["مفعّل", "Approved", "good"],
  rejected: ["مرفوض", "Rejected", "bad"],
  suspended: ["موقوف", "Suspended", "bad"],
};

export const bookingStatus: StatusMap = {
  requested: ["بانتظار الموافقة", "Awaiting approval", "warn"],
  reschedule_proposed: ["موعد مقترح", "New time proposed", "warn"],
  awaiting_payment: ["بانتظار الدفع", "Awaiting payment", "warn"],
  payment_submitted: ["تم رفع الإيصال", "Receipt uploaded", "brand"],
  payment_confirmed: ["مؤكد", "Confirmed", "good"],
  completed: ["مكتمل", "Completed", "good"],
  declined: ["مرفوض", "Declined", ""],
  cancelled_by_bride: ["ألغته العروس", "Cancelled by bride", ""],
  cancelled_by_provider: ["ألغته المزوّدة", "Cancelled by provider", ""],
  expired: ["منتهي", "Expired", ""],
  disputed: ["نزاع", "Disputed", "bad"],
};

export const reviewStatus: StatusMap = {
  pending: ["بانتظار المراجعة", "Pending", "warn"],
  approved: ["منشور", "Published", "good"],
  rejected: ["مرفوض", "Rejected", "bad"],
  hidden: ["مخفي", "Hidden", ""],
};

export const reportStatus: StatusMap = {
  open: ["مفتوح", "Open", "warn"],
  actioned: ["تم الإجراء", "Actioned", "good"],
  dismissed: ["مرفوض", "Dismissed", ""],
};

export const ticketStatus: StatusMap = {
  open: ["مفتوحة", "Open", "warn"],
  answered: ["تم الرد", "Answered", "good"],
  closed: ["مغلقة", "Closed", ""],
};

export const paymentStatus: StatusMap = {
  initiated: ["لم يكتمل", "Not completed", ""],
  captured: ["مدفوعة", "Paid", "good"],
  failed: ["فشلت", "Failed", "bad"],
  review: ["تحتاج مراجعة", "Needs review", "warn"],
};

export const reportReason: LabelMap = {
  spam: ["إزعاج/إعلان", "Spam / ad"], inappropriate: ["غير لائق", "Inappropriate"], fake: ["مزيف", "Fake"],
  harassment: ["إساءة", "Harassment"], fraud: ["احتيال", "Fraud"], other: ["أخرى", "Other"],
};

export const disputeReason: LabelMap = {
  payment_not_received: ["لم يصل المبلغ", "Payment not received"], receipt_fake: ["إيصال غير صحيح", "Invalid receipt"],
  no_show: ["عدم الحضور", "No-show"], service_issue: ["مشكلة في الخدمة", "Service issue"],
  refund: ["طلب استرداد", "Refund request"], other: ["أخرى", "Other"],
};

export const role: LabelMap = { bride: ["عروس", "Bride"], provider: ["مقدّمة خدمة", "Provider"] };

/** Who opened a dispute, filed a report, etc. */
export const party: LabelMap = { bride: ["العروس", "Bride"], provider: ["مقدّمة الخدمة", "Provider"], admin: ["الإدارة", "Admin"], system: ["النظام", "System"] };
