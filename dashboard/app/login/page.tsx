"use client";
import { useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { Suspense } from "react";
import { supabaseBrowser } from "@/lib/supabase/client";

function LoginForm() {
  const router = useRouter();
  const params = useSearchParams();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(params.get("error") === "not_admin" ? "هذا الحساب ليس من فريق الإدارة." : "");

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError("");
    const supabase = supabaseBrowser();
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    setBusy(false);
    if (error) {
      setError("البريد أو كلمة المرور غير صحيحة.");
      return;
    }
    router.replace("/");
    router.refresh();
  }

  return (
    <main className="login">
      <form className="card stack" onSubmit={submit}>
        <div>
          <h1 style={{ color: "var(--primary)" }}>منيتي</h1>
          <p className="muted">لوحة الإدارة</p>
        </div>
        {error && <div className="flash err">{error}</div>}
        <label>
          البريد الإلكتروني
          <input type="email" required dir="ltr" autoComplete="username" value={email} onChange={(e) => setEmail(e.target.value)} />
        </label>
        <label>
          كلمة المرور
          <input type="password" required dir="ltr" autoComplete="current-password" value={password} onChange={(e) => setPassword(e.target.value)} />
        </label>
        <button type="submit" disabled={busy}>{busy ? "…" : "دخول"}</button>
      </form>
    </main>
  );
}

export default function LoginPage() {
  return (
    <Suspense>
      <LoginForm />
    </Suspense>
  );
}
