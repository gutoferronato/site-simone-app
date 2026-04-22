import { Resend } from "resend";
import type { Lead, LeadTemperature } from "@prisma/client";

export async function sendLeadNotification(
  lead: Pick<Lead, "id" | "name" | "email" | "phone" | "score" | "source"> & {
    temperature: LeadTemperature;
  }
) {
  const apiKey = process.env.RESEND_API_KEY;
  const from = process.env.RESEND_FROM;
  const to = process.env.SALES_NOTIFICATION_EMAIL;

  if (!apiKey || !from || !to) return;

  const resend = new Resend(apiKey);

  await resend.emails.send({
    from,
    to,
    subject: `Novo lead capturado • ${lead.temperature}`,
    html: `
      <div style="font-family:Arial,sans-serif;padding:24px">
        <h2>Novo lead capturado</h2>
        <p><strong>Nome:</strong> ${lead.name ?? "-"}</p>
        <p><strong>Email:</strong> ${lead.email ?? "-"}</p>
        <p><strong>Telefone:</strong> ${lead.phone ?? "-"}</p>
        <p><strong>Score:</strong> ${lead.score}</p>
        <p><strong>Temperatura:</strong> ${lead.temperature}</p>
        <p><strong>Origem:</strong> ${lead.source ?? "-"}</p>
        <p><strong>ID:</strong> ${lead.id}</p>
      </div>
    `,
  });
}
