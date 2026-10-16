"use server";
import { cookies } from "next/headers";
import { LANG_COOKIE } from "@/lib/i18n";

/** Switches the dashboard language; the current page re-renders with the new cookie. */
export async function setLang(form: FormData) {
  const lang = form.get("lang") === "en" ? "en" : "ar";
  (await cookies()).set(LANG_COOKIE, lang, { path: "/", maxAge: 60 * 60 * 24 * 365, sameSite: "lax" });
}
