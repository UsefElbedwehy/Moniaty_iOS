import { getLang } from "@/lib/i18n";
import { LoginForm } from "@/components/LoginForm";
import { LangSwitch } from "@/components/LangSwitch";

export default async function LoginPage() {
  const lang = await getLang();
  return (
    <>
      <div style={{ position: "absolute", insetInlineEnd: 16, top: 16 }}><LangSwitch lang={lang} /></div>
      <LoginForm lang={lang} />
    </>
  );
}
