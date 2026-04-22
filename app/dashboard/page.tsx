import { redirect } from "next/navigation";
import { auth } from "@/auth";
import { prisma } from "@/lib/prisma";
import { formatDate } from "@/lib/utils";

export const dynamic = "force-dynamic";

function StatCard({
  title,
  value,
  description,
}: {
  title: string;
  value: string | number;
  description: string;
}) {
  return (
    <div className="rounded-[28px] border border-white/10 bg-white/5 p-6 backdrop-blur">
      <p className="text-xs font-semibold uppercase tracking-[0.25em] text-brand-gold">{title}</p>
      <p className="mt-3 text-4xl font-semibold text-white">{value}</p>
      <p className="mt-2 text-sm leading-7 text-white/65">{description}</p>
    </div>
  );
}

export default async function DashboardPage() {
  const session = await auth();

  if (!session?.user) {
    redirect("/signin");
  }

  const [totalLeads, hotLeads, warmLeads, totalEvents, latestLeads] = await Promise.all([
    prisma.lead.count(),
    prisma.lead.count({ where: { temperature: "HOT" } }),
    prisma.lead.count({ where: { temperature: "WARM" } }),
    prisma.pageEvent.count(),
    prisma.lead.findMany({
      take: 10,
      orderBy: { createdAt: "desc" },
      select: {
        id: true,
        name: true,
        email: true,
        phone: true,
        score: true,
        temperature: true,
        status: true,
        createdAt: true,
      },
    }),
  ]);

  return (
    <main className="mx-auto max-w-6xl px-4 py-10 md:px-6">
      <div className="mb-8">
        <p className="text-xs font-semibold uppercase tracking-[0.3em] text-brand-gold">
          dashboard protegido
        </p>
        <h1 className="mt-3 font-serif text-4xl text-white md:text-5xl">
          Visão rápida da inteligência comercial
        </h1>
        <p className="mt-3 max-w-3xl text-sm leading-7 text-white/70">
          Área interna com visão do CRM, volume de eventos e temperatura dos leads capturados pela
          página principal.
        </p>
      </div>

      <section className="grid gap-5 md:grid-cols-4">
        <StatCard
          title="Leads totais"
          value={totalLeads}
          description="Quantidade acumulada de contatos no CRM."
        />
        <StatCard
          title="Leads quentes"
          value={hotLeads}
          description="Leads com score alto e intenção mais forte."
        />
        <StatCard
          title="Leads mornos"
          value={warmLeads}
          description="Leads em aquecimento, acompanhados pelo sistema."
        />
        <StatCard
          title="Eventos"
          value={totalEvents}
          description="Todas as interações capturadas no tracking."
        />
      </section>

      <section className="mt-8 overflow-hidden rounded-[28px] border border-white/10 bg-white/5 backdrop-blur">
        <div className="border-b border-white/10 px-6 py-5">
          <h2 className="font-serif text-2xl text-white">Últimos leads</h2>
        </div>

        <div className="overflow-x-auto">
          <table className="min-w-full text-left text-sm">
            <thead className="bg-white/5 text-white/60">
              <tr>
                <th className="px-6 py-4 font-medium">Nome</th>
                <th className="px-6 py-4 font-medium">E-mail</th>
                <th className="px-6 py-4 font-medium">Telefone</th>
                <th className="px-6 py-4 font-medium">Score</th>
                <th className="px-6 py-4 font-medium">Temperatura</th>
                <th className="px-6 py-4 font-medium">Status</th>
                <th className="px-6 py-4 font-medium">Criado em</th>
              </tr>
            </thead>
            <tbody>
              {latestLeads.map((lead) => (
                <tr key={lead.id} className="border-t border-white/10 text-white/80">
                  <td className="px-6 py-4">{lead.name ?? "-"}</td>
                  <td className="px-6 py-4">{lead.email ?? "-"}</td>
                  <td className="px-6 py-4">{lead.phone ?? "-"}</td>
                  <td className="px-6 py-4">{lead.score}</td>
                  <td className="px-6 py-4">{lead.temperature}</td>
                  <td className="px-6 py-4">{lead.status}</td>
                  <td className="px-6 py-4">{formatDate(lead.createdAt)}</td>
                </tr>
              ))}

              {latestLeads.length === 0 && (
                <tr>
                  <td className="px-6 py-6 text-white/60" colSpan={7}>
                    Nenhum lead encontrado ainda.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </section>
    </main>
  );
}
