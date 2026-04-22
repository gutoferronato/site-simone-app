import TrackedPremiumLink from "@/components/ui/TrackedPremiumLink";

export default function Home() {
  return (
    <main className="min-h-screen bg-wineDark text-white px-6 pb-12 pt-32 flex flex-col items-center">
      {/* TOPO */}
      <div className="w-full max-w-xl text-center mb-10">
        <h1 className="text-3xl md:text-4xl font-serif mb-2">
          Simone Matos
        </h1>

        <p className="text-sm text-zinc-300">
          Psicóloga • Sexualidade feminina • Cura emocional
        </p>
      </div>

      {/* LINKS */}
      <div id="links" className="w-full max-w-xl flex flex-col gap-6">
        <TrackedPremiumLink
          highlight
          title='👉 Jornada "Destrave Seu Padrão Emocional em 1 Dia"'
          description="Para mulheres que estão cansadas de se sentir rejeitadas, não pertencentes e repetindo os mesmos padrões. Essa jornada é para quem decidiu mudar."
          links={[
            {
              label: "Inscreva-se na jornada!",
              href: "https://wa.me/5571992436919",
            },
            {
              label: "Entre no nosso grupo!",
              href: "https://chat.whatsapp.com/CSiIVTUAoIgFIAfhSwDrJZ?mode=gi_t",
            },
          ]}
        />

        <TrackedPremiumLink
          title="👉 E-book protocolo autoestima"
          description="Um protocolo direto para você sair da autossabotagem emocional e reconstruir sua autoestima com consciência."
          links={[
            {
              label: "Comprar já!",
              href: "https://pay.kiwify.com.br/ZV8h7Sm",
            },
          ]}
        />

        <TrackedPremiumLink
          title="👉 Baralho para casais"
          description="Para mulheres e casais que querem sair do bloqueio e viver o prazer com verdade e profundidade."
          links={[
            {
              label: "Comprar já!",
              href: "https://pay.kiwify.com.br/GCikzsi",
            },
          ]}
        />
      </div>

      {/* MANIFESTO */}
      <div className="max-w-xl mt-14 text-center text-zinc-300 text-sm leading-relaxed">
        Você não atrai homens errados por azar.
        <br />
        Você repete padrões que ainda não foram curados.
        <br />
        <br />
        Enquanto você não se reconecta com quem você é,
        <br />
        continua aceitando menos do que merece.
        <br />
        <br />
        Aqui não é sobre técnica.
        <br />
        É sobre voltar para si.
      </div>

      {/* CHAMADA FINAL CURTA */}
      <div id="contato" className="w-full max-w-xl mt-12">
        <div className="bg-white/5 border border-white/10 rounded-[28px] p-6 backdrop-blur-xl text-center">
          <h3 className="text-lg font-semibold mb-2">Comece por você</h3>

          <p className="text-sm text-zinc-400">
            Escolha acima o caminho que mais faz sentido para o seu momento e
            dê o primeiro passo para destravar seu padrão emocional.
          </p>
        </div>
      </div>
    </main>
  );
}