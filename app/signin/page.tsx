import Image from "next/image";
import { signIn } from "@/auth";

type SignInPageProps = {
  searchParams: Promise<{ callbackUrl?: string }>;
};

export default async function SignInPage({ searchParams }: SignInPageProps) {
  const params = await searchParams;
  const callbackUrl = params.callbackUrl ?? "/dashboard";

  return (
    <main className="mx-auto flex min-h-[calc(100vh-80px)] max-w-6xl items-center px-4 py-12 md:px-6">
      <div className="mx-auto w-full max-w-md rounded-[32px] border border-white/10 bg-white/5 p-8 shadow-[0_30px_80px_-40px_rgba(0,0,0,1)] backdrop-blur">
        <div className="mb-8 text-center">
          <Image
            src="/logo-sm.svg"
            alt="Simone Matos"
            width={80}
            height={80}
            className="mx-auto h-20 w-20"
            priority
          />
          <h1 className="mt-5 font-serif text-4xl text-white">Entrar com Google</h1>
          <p className="mt-3 text-sm leading-7 text-white/70">
            A área protegida usa autenticação com Google e mantém o dashboard acessível apenas para
            usuários autorizados.
          </p>
        </div>

        <form
          action={async () => {
            "use server";
            await signIn("google", { redirectTo: callbackUrl });
          }}
        >
          <button
            type="submit"
            className="w-full rounded-full bg-brand-gold px-5 py-3 font-medium text-brand-wine-darker transition hover:opacity-90"
          >
            Continuar com Google
          </button>
        </form>
      </div>
    </main>
  );
}
