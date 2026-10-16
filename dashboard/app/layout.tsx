import type { Metadata } from "next";
import { i18n } from "@/lib/i18n";
import "./globals.css";

export async function generateMetadata(): Promise<Metadata> {
  const { t } = await i18n();
  return {
    title: t("منيتي — لوحة الإدارة", "Munyati — Admin"),
    robots: { index: false, follow: false },
  };
}

export default async function RootLayout({ children }: { children: React.ReactNode }) {
  const { lang, dir } = await i18n();
  return (
    <html lang={lang} dir={dir}>
      <body>{children}</body>
    </html>
  );
}
