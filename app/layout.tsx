import type { Metadata } from "next";
import { Inter, Cormorant_Garamond } from "next/font/google";
import "./globals.css";
import Header from "@/components/layout/Header";
import { PageViewTracker } from "@/components/analytics/PageViewTracker";

const inter = Inter({
  subsets: ["latin"],
  variable: "--font-inter",
});

const cormorant = Cormorant_Garamond({
  subsets: ["latin"],
  variable: "--font-serif",
  weight: ["400", "500", "600", "700"],
});

export const metadata: Metadata = {
  title: "Simone Matos • Terapeuta Psicóloga",
  description:
    "Simone Matos é terapeuta psicóloga especializada em ajudar mulheres a superar inseguranças, traumas e bloqueios emocionais.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="pt-BR">
      <body
        className={`${inter.variable} ${cormorant.variable} bg-wine text-white antialiased`}
      >
        <div className="min-h-screen bg-[linear-gradient(180deg,#5b0710_0%,#43050a_35%,#2a0206_100%)]">
          <Header />
          <PageViewTracker />
          {children}
        </div>
      </body>
    </html>
  );
}