"use client";

import { useState } from "react";
import { useForm } from "react-hook-form";
import { trackEvent, getClientContext } from "@/lib/tracking";

type FormValues = {
  name: string;
  email: string;
  phone?: string;
  instagram?: string;
  message?: string;
  interestLevel: "LOW" | "MEDIUM" | "HIGH";
  consentMarketing: boolean;
  honeypot?: string;
};

export function LeadCaptureForm() {
  const [result, setResult] = useState<null | { message: string; ok: boolean }>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const form = useForm<FormValues>({
    defaultValues: {
      name: "",
      email: "",
      phone: "",
      instagram: "",
      message: "",
      interestLevel: "MEDIUM",
      consentMarketing: true,
      honeypot: "",
    },
  });

  const onSubmit = async (values: FormValues) => {
    setIsSubmitting(true);
    setResult(null);

    try {
      trackEvent({
        name: "lead_form_open",
        category: "conversion",
      });

      const payload = {
        ...values,
        ...getClientContext(),
        consentAnalytics: true,
      };

      const response = await fetch("/api/leads", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify(payload),
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data?.error ?? "Não foi possível enviar.");
      }

      trackEvent({
        name: "lead_created",
        category: "conversion",
        metadata: {
          leadId: data.leadId,
          score: data.score,
          temperature: data.temperature,
        },
      });

      setResult({
        ok: true,
        message: "Lead capturado com sucesso. O CRM, o score e o tracking foram atualizados.",
      });

      form.reset();
    } catch (error) {
      setResult({
        ok: false,
        message: error instanceof Error ? error.message : "Erro inesperado ao enviar.",
      });
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <section
      id="captura"
      className="rounded-[32px] border border-white/10 bg-white/5 p-6 shadow-[0_30px_90px_-40px_rgba(0,0,0,1)] backdrop-blur md:p-8"
    >
      <div className="mb-6">
        <p className="text-xs font-semibold uppercase tracking-[0.3em] text-brand-gold">
          CRM + score + tracking
        </p>
        <h3 className="mt-3 font-serif text-3xl text-white">
          Formulário real para testar a captura do sistema
        </h3>
        <p className="mt-3 max-w-2xl text-sm leading-7 text-white/70">
          Ao enviar este formulário, o sistema cria ou atualiza o lead, associa os eventos
          anônimos anteriores, recalcula o score e registra tudo no histórico.
        </p>
      </div>

      <form onSubmit={form.handleSubmit(onSubmit)} className="grid gap-4 md:grid-cols-2">
        <input
          type="text"
          className="hidden"
          tabIndex={-1}
          autoComplete="off"
          {...form.register("honeypot")}
        />

        <label className="grid gap-2">
          <span className="text-sm text-white/75">Nome</span>
          <input
            className="rounded-2xl border border-white/10 bg-brand-wine-darker px-4 py-3 text-white outline-none ring-0 transition placeholder:text-white/35 focus:border-brand-gold/50"
            placeholder="Seu nome"
            {...form.register("name", { required: true, minLength: 2 })}
          />
        </label>

        <label className="grid gap-2">
          <span className="text-sm text-white/75">E-mail</span>
          <input
            type="email"
            className="rounded-2xl border border-white/10 bg-brand-wine-darker px-4 py-3 text-white outline-none transition placeholder:text-white/35 focus:border-brand-gold/50"
            placeholder="voce@email.com"
            {...form.register("email", { required: true })}
          />
        </label>

        <label className="grid gap-2">
          <span className="text-sm text-white/75">WhatsApp</span>
          <input
            className="rounded-2xl border border-white/10 bg-brand-wine-darker px-4 py-3 text-white outline-none transition placeholder:text-white/35 focus:border-brand-gold/50"
            placeholder="(00) 00000-0000"
            {...form.register("phone")}
          />
        </label>

        <label className="grid gap-2">
          <span className="text-sm text-white/75">Instagram</span>
          <input
            className="rounded-2xl border border-white/10 bg-brand-wine-darker px-4 py-3 text-white outline-none transition placeholder:text-white/35 focus:border-brand-gold/50"
            placeholder="@seuinstagram"
            {...form.register("instagram")}
          />
        </label>

        <label className="grid gap-2 md:col-span-2">
          <span className="text-sm text-white/75">Nível de interesse</span>
          <select
            className="rounded-2xl border border-white/10 bg-brand-wine-darker px-4 py-3 text-white outline-none transition focus:border-brand-gold/50"
            {...form.register("interestLevel")}
          >
            <option value="LOW">Baixo</option>
            <option value="MEDIUM">Médio</option>
            <option value="HIGH">Alto</option>
          </select>
        </label>

        <label className="grid gap-2 md:col-span-2">
          <span className="text-sm text-white/75">Mensagem</span>
          <textarea
            rows={5}
            className="rounded-2xl border border-white/10 bg-brand-wine-darker px-4 py-3 text-white outline-none transition placeholder:text-white/35 focus:border-brand-gold/50"
            placeholder="Conte um pouco do que você busca."
            {...form.register("message")}
          />
        </label>

        <label className="md:col-span-2 flex items-start gap-3 rounded-2xl border border-white/10 bg-brand-wine-darker/80 p-4 text-sm text-white/70">
          <input
            type="checkbox"
            className="mt-1 h-4 w-4 accent-brand-gold"
            {...form.register("consentMarketing")}
          />
          Aceito receber comunicações úteis e canceláveis por e-mail.
        </label>

        <div className="md:col-span-2 flex flex-col gap-3 sm:flex-row sm:items-center">
          <button
            type="submit"
            disabled={isSubmitting}
            className="inline-flex items-center justify-center rounded-full bg-brand-gold px-6 py-3 font-medium text-brand-wine-darker transition hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-60"
          >
            {isSubmitting ? "Enviando..." : "Salvar lead no sistema"}
          </button>

          {result && (
            <p className={result.ok ? "text-sm text-emerald-300" : "text-sm text-red-300"}>
              {result.message}
            </p>
          )}
        </div>
      </form>
    </section>
  );
}
