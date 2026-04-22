"use client";

import Link from "next/link";

export default function Header() {
  return (
    <header className="w-full fixed top-0 left-0 z-50 backdrop-blur-xl bg-wineDark/80 border-b border-white/10">
      <div className="max-w-6xl mx-auto px-6 py-4 flex items-center justify-between">
        <div className="flex flex-col leading-tight">
          <span className="font-serif text-lg tracking-wide">
            Simone Matos
          </span>

          <span className="text-[10px] uppercase tracking-[0.25em] text-zinc-400">
            TERAPEUTA PSICÓLOGA
          </span>
        </div>

        <nav className="hidden md:flex items-center gap-8 text-sm text-zinc-300">
          <Link href="/" className="hover:text-white transition-colors">
            Início
          </Link>

          <Link href="/#links" className="hover:text-white transition-colors">
            Links
          </Link>
        </nav>
      </div>
    </header>
  );
}