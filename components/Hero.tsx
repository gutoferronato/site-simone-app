import Image from "next/image";
import { ArrowDownRight, PlayCircle } from "lucide-react";

export function Hero() {
  return (
    <section id="hero" className="relative overflow-hidden">
      <div className="absolute inset-0 bg-[radial-gradient(circle_at_top,rgba(243,193,93,0.14),transparent_40%),radial-gradient(circle_at_bottom,rgba(255,255,255,0.07),transparent_30%)]" />
      <div className="relative mx-auto grid max-w-6xl items-center gap-10 px-4 py-14 md:px-6 md:py-24 lg:grid-cols-[1.1fr_0.9fr]">
        <div className="max-w-2xl">
          <div className="mb-6 inline-flex items-center gap-3 rounded-full border border-brand-gold/25 bg-white/5 px-4 py-2 text-sm text-brand-gold-light backdrop-blur">
            <Image
              src="/logo-sm.svg"
              alt="Logotipo Simone Matos"
              width={28}
              height={28}
              className="h-7 w-7"
            />
            Linktree premium com infraestrutura de CRM, tracking e conversão
          </div>

          <h1 className="max-w-3xl font-serif text-4xl leading-tight text-white md:text-6xl">
            Uma página elegante por fora.
            <span className="block text-brand-gold">
              Uma máquina de conversão por trás.
            </span>
          </h1>

          <p className="mt-6 max-w-2xl text-base leading-8 text-white/75 md:text-lg">
            Este projeto já nasce com captura de leads, score de interesse, login com Google,
            rastreamento de comportamento, APIs seguras e base preparada para expandir para
            novas páginas sem perder a inteligência do sistema.
          </p>

          <div className="mt-8 flex flex-col gap-3 sm:flex-row">
            <a
              href="#links"
              className="inline-flex items-center justify-center gap-2 rounded-full bg-brand-gold px-6 py-3 font-medium text-brand-wine-darker transition hover:opacity-90"
            >
              Ver links estratégicos
              <ArrowDownRight className="h-4 w-4" />
            </a>
            <a
              href="#captura"
              className="inline-flex items-center justify-center gap-2 rounded-full border border-white/15 bg-white/5 px-6 py-3 font-medium text-white transition hover:bg-white/10"
            >
              Capturar lead de teste
              <PlayCircle className="h-4 w-4" />
            </a>
          </div>
        </div>

        <div className="relative">
          <div className="overflow-hidden rounded-[32px] border border-white/10 bg-brand-wine-darker shadow-[0_30px_80px_-35px_rgba(0,0,0,1)]">
            <div className="relative aspect-[10/12] w-full bg-[linear-gradient(180deg,rgba(0,0,0,0.1),rgba(58,5,9,0.4)),radial-gradient(circle_at_top,rgba(243,193,93,0.24),transparent_40%),linear-gradient(135deg,#1a0204,#5b0710,#2d0408)]">
              <video
                className="absolute inset-0 h-full w-full object-cover opacity-50"
                src="/video-secao-hero.mp4"
                autoPlay
                muted
                loop
                playsInline
                preload="metadata"
              />
              <div className="absolute inset-0 bg-gradient-to-t from-brand-wine-darker via-brand-wine-darker/40 to-transparent" />
              <div className="absolute inset-x-0 bottom-0 p-8">
                <div className="mb-4 inline-flex items-center rounded-full border border-brand-gold/30 bg-black/30 px-3 py-1 text-xs uppercase tracking-[0.25em] text-brand-gold backdrop-blur">
                  vídeo hero substituível
                </div>
                <h2 className="max-w-md font-serif text-3xl leading-tight text-white">
                  Troque o arquivo <span className="text-brand-gold">video-secao-hero.mp4</span> pelo seu vídeo.
                </h2>
                <p className="mt-3 max-w-md text-sm leading-7 text-white/70">
                  Enquanto isso, a seção já está pronta com design premium, overlay elegante e CTA
                  rastreável para capturar comportamento e intenção.
                </p>
              </div>
            </div>
          </div>

          <div className="absolute -bottom-5 -left-5 hidden rounded-3xl border border-brand-gold/25 bg-brand-wine/70 px-5 py-4 shadow-xl backdrop-blur md:block">
            <p className="text-xs uppercase tracking-[0.25em] text-brand-gold">tracking ativo</p>
            <p className="mt-1 text-lg font-semibold text-white">page_view • click • lead</p>
          </div>
        </div>
      </div>
    </section>
  );
}
