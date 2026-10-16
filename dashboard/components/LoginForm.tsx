"use client";
import { useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { Suspense } from "react";
import { supabaseBrowser } from "@/lib/supabase/client";
import type { Lang } from "@/lib/i18n";

function Form({ lang }: { lang: Lang }) {
  const t = (ar: string, en: string) => (lang === "ar" ? ar : en);
  const router = useRouter();
  const params = useSearchParams();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(params.get("error") === "not_admin" ? t("هذا الحساب ليس من فريق الإدارة.", "This account isn't on the admin team.") : "");

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError("");
    const supabase = supabaseBrowser();
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    setBusy(false);
    if (error) {
      setError(t("البريد أو كلمة المرور غير صحيحة.", "Wrong email or password."));
      return;
    }
    router.replace("/");
    router.refresh();
  }

  return (
    <main className="login">
      <form className="card stack" onSubmit={submit}>
        <div>
          <h1 style={{ color: "var(--primary)" }}>{t("منيتي", "Munyati")}</h1>
          <p className="muted">{t("لوحة الإدارة", "Admin dashboard")}</p>
        </div>
        {error && <div className="flash err">{error}</div>}
        <label>
          {t("البريد الإلكتروني", "Email")}
          <input type="email" required dir="ltr" autoComplete="username" value={email} onChange={(e) => setEmail(e.target.value)} />
        </label>
        <label>
          {t("كلمة المرور", "Password")}
          <input type="password" required dir="ltr" autoComplete="current-password" value={password} onChange={(e) => setPassword(e.target.value)} />
        </label>
        <button type="submit" disabled={busy}>{busy ? "…" : t("دخول", "Sign in")}</button>
      </form>
    </main>
  );
}

export function LoginForm({ lang }: { lang: Lang }) {
  return (
    <Suspense>
      <Form lang={lang} />
    </Suspense>
  );
}
