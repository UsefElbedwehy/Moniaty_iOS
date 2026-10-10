export const providerStatus: Record<string, [string, string]> = {
  pending: ["قيد المراجعة", "warn"],
  approved: ["مفعّل", "good"],
  rejected: ["مرفوض", "bad"],
  suspended: ["موقوف", "bad"],
};

export const bookingStatus: Record<string, [string, string]> = {
  requested: ["بانتظار الموافقة", "warn"],
  reschedule_proposed: ["موعد مقترح", "warn"],
  awaiting_payment: ["بانتظار الدفع", "warn"],
  payment_submitted: ["تم رفع الإيصال", "brand"],
  payment_confirmed: ["مؤكد", "good"],
  completed: ["مكتمل", "good"],
  declined: ["مرفوض", ""],
  cancelled_by_bride: ["ألغته العروس", ""],
  cancelled_by_provider: ["ألغته المزوّدة", ""],
  expired: ["منتهي", ""],
  disputed: ["نزاع", "bad"],
};

export const reviewStatus: Record<string, [string, string]> = {
  pending: ["بانتظار المراجعة", "warn"],
  approved: ["منشور", "good"],
  rejected: ["مرفوض", "bad"],
  hidden: ["مخفي", ""],
};

export const reportStatus: Record<string, [string, string]> = {
  open: ["مفتوح", "warn"],
  actioned: ["تم الإجراء", "good"],
  dismissed: ["مرفوض", ""],
};

export const ticketStatus: Record<string, [string, string]> = {
  open: ["مفتوحة", "warn"],
  answered: ["تم الرد", "good"],
  closed: ["مغلقة", ""],
};

export const paymentStatus: Record<string, [string, string]> = {
  initiated: ["لم يكتمل", ""],
  captured: ["مدفوعة", "good"],
  failed: ["فشلت", "bad"],
  review: ["تحتاج مراجعة", "warn"],
};

export const reportReason: Record<string, string> = {
  spam: "إزعاج/إعلان", inappropriate: "غير لائق", fake: "مزيف", harassment: "إساءة", fraud: "احتيال", other: "أخرى",
};

export const disputeReason: Record<string, string> = {
  payment_not_received: "لم يصل المبلغ", receipt_fake: "إيصال غير صحيح", no_show: "عدم الحضور",
  service_issue: "مشكلة في الخدمة", refund: "طلب استرداد", other: "أخرى",
};

export const role: Record<string, string> = { bride: "عروس", provider: "مقدّمة خدمة" };
