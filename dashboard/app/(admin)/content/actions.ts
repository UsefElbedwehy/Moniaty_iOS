"use server";
import { supabaseServer } from "@/lib/supabase/server";
import { done, str, bool } from "@/lib/act";

export async function savePage(form: FormData) {
  const supabase = await supabaseServer();
  const slug = str(form, "slug").toLowerCase().replace(/[^a-z0-9-]/g, "-");
  const { error } = await supabase.from("cms_pages").upsert({
    slug, lang: str(form, "lang"), title: str(form, "title"), body_markdown: str(form, "body"), is_published: bool(form, "is_published"),
  });
  done(`/content?page=${slug}&lang=${str(form, "lang")}`, error);
}

export async function saveString(form: FormData) {
  const supabase = await supabaseServer();
  const key = str(form, "key");
  const value = str(form, "value");
  const lang = str(form, "lang");
  // An empty value removes the override, so the app falls back to its built-in text.
  const { error } = value
    ? await supabase.from("app_strings").upsert({ key, lang, value })
    : await supabase.from("app_strings").delete().eq("key", key).eq("lang", lang);
  done("/content?tab=strings", error);
}
