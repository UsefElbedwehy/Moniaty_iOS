"use server";
import { supabaseServer } from "@/lib/supabase/server";
import { done, str, bool, num } from "@/lib/act";

type Config = Record<string, unknown>;

async function current(): Promise<Config> {
  const supabase = await supabaseServer();
  const { data } = await supabase.from("app_config").select("config").eq("id", 1).single();
  return (data?.config ?? {}) as Config;
}

async function write(config: Config) {
  const supabase = await supabaseServer();
  const { error } = await supabase.from("app_config").update({ config }).eq("id", 1);
  done("/settings", error);
}

const obj = (v: unknown) => (v && typeof v === "object" && !Array.isArray(v) ? (v as Config) : {});

/** The common settings as a form; everything else in the JSON is kept as is. */
export async function saveSettings(form: FormData) {
  const c = await current();
  const smsEvents = obj(c.sms_events);
  for (const key of Object.keys(smsEvents)) smsEvents[key] = bool(form, `sms_${key}`);
  const contacts = str(form, "contacts").split("\n").map((l) => l.trim()).filter(Boolean).map((line) => {
    const [kind, ...rest] = line.split(":");
    return { id: kind.trim(), kind: kind.trim(), value: rest.join(":").trim() };
  }).filter((m) => ["email", "whatsapp", "phone"].includes(m.kind) && m.value);
  const next: Config = {
    ...c,
    trial_days: num(form, "trial_days"),
    trial_plan_id: str(form, "trial_plan_id"),
    timeouts_hours: {
      request: num(form, "t_request"), proposal: num(form, "t_proposal"),
      payment: num(form, "t_payment"), receipt_confirmation: num(form, "t_receipt"),
    },
    review_window_days: num(form, "review_window_days"),
    reviews_premoderation: bool(form, "reviews_premoderation"),
    banned_words: str(form, "banned_words").split("\n").map((w) => w.trim()).filter(Boolean),
    sms_events: smsEvents,
    feature_flags: { ...obj(c.feature_flags), maintenanceMode: bool(form, "maintenance") },
    update: {
      ...obj(c.update),
      min_required_version: str(form, "min_version") || null,
      force_update: bool(form, "force_update"),
      update_message: str(form, "update_message") || null,
      store_url: str(form, "store_url") || null,
    },
    support: { ...obj(c.support), help_center_url: str(form, "help_center_url") || null, contact_methods: contacts },
  };
  await write(next);
}

/** Advanced: replace the whole JSON (validated). */
export async function saveRawConfig(form: FormData) {
  let parsed: unknown;
  try {
    parsed = JSON.parse(str(form, "json"));
  } catch {
    done("/settings", { message: "JSON غير صالح" });
  }
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) done("/settings", { message: "يجب أن يكون كائن JSON" });
  await write(parsed as Config);
}
