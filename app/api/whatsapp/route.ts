import { NextRequest, NextResponse } from "next/server";
import twilio from "twilio";
import { answerWhatsAppMessage } from "@/lib/chatbot";
import { prisma } from "@/lib/prisma";

export const runtime = "nodejs";

function xmlEscape(value: string) {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&apos;");
}

function twimlMessage(message: string) {
  return `<?xml version="1.0" encoding="UTF-8"?>
<Response>
  <Message>${xmlEscape(message)}</Message>
</Response>`;
}

function formDataToObject(params: URLSearchParams) {
  const obj: Record<string, string> = {};

  for (const [key, value] of params.entries()) {
    obj[key] = value;
  }

  return obj;
}

async function recordWhatsAppEvent(input: {
  name: string;
  from?: string;
  body?: string;
  messageSid?: string;
  profileName?: string;
  metadata?: Record<string, unknown>;
}) {
  try {
    await prisma.pageEvent.create({
      data: {
        name: input.name,
        category: "whatsapp",
        anonymousId: input.from,
        metadata: {
          from: input.from,
          body: input.body,
          messageSid: input.messageSid,
          profileName: input.profileName,
          ...input.metadata,
        },
      },
    });
  } catch (error) {
    console.error("Erro ao registrar evento WhatsApp:", error);
  }
}

function validateTwilioSignature({
  req,
  rawBody,
}: {
  req: NextRequest;
  rawBody: string;
}) {
  const shouldValidate = process.env.TWILIO_VALIDATE_SIGNATURE === "true";

  if (!shouldValidate) return true;

  const authToken = process.env.TWILIO_AUTH_TOKEN;
  const publicUrl = process.env.TWILIO_WEBHOOK_PUBLIC_URL;
  const signature = req.headers.get("x-twilio-signature");

  if (!authToken || !publicUrl || !signature) {
    return false;
  }

  const params = formDataToObject(new URLSearchParams(rawBody));

  return twilio.validateRequest(authToken, signature, publicUrl, params);
}

export async function GET() {
  return NextResponse.json({
    ok: true,
    route: "/api/whatsapp",
    message: "WhatsApp webhook ativo. Use POST pelo Twilio.",
  });
}

export async function POST(req: NextRequest) {
  const rawBody = await req.text();

  const isValid = validateTwilioSignature({
    req,
    rawBody,
  });

  if (!isValid) {
    return new NextResponse("Invalid Twilio signature", {
      status: 403,
    });
  }

  const params = new URLSearchParams(rawBody);

  const from = params.get("From") || undefined;
  const body = params.get("Body") || "";
  const messageSid = params.get("MessageSid") || undefined;
  const profileName = params.get("ProfileName") || undefined;

  if (!body.trim()) {
    return new NextResponse(
      twimlMessage("Pode me mandar sua dúvida em texto?"),
      {
        status: 200,
        headers: {
          "Content-Type": "text/xml; charset=utf-8",
        },
      }
    );
  }

  await recordWhatsAppEvent({
    name: "whatsapp_message_received",
    from,
    body,
    messageSid,
    profileName,
  });

  try {
    const result = await answerWhatsAppMessage({
      userMessage: body,
      userPhone: from,
      userName: profileName,
    });

    const reply =
      result.reply?.trim() ||
      "Posso te ajudar com informações sobre o atendimento. Me diga sua dúvida principal.";

    await recordWhatsAppEvent({
      name: "whatsapp_message_replied",
      from,
      body: reply,
      messageSid,
      profileName,
      metadata: {
        shouldHandoff: result.shouldHandoff,
        reason: result.reason,
      },
    });

    return new NextResponse(twimlMessage(reply), {
      status: 200,
      headers: {
        "Content-Type": "text/xml; charset=utf-8",
      },
    });
  } catch (error) {
    console.error("Erro no bot WhatsApp:", error);

    const fallback =
      "Tive uma instabilidade aqui, mas posso continuar tentando te ajudar. Me mande sua dúvida de forma simples.";

    await recordWhatsAppEvent({
      name: "whatsapp_bot_error",
      from,
      body,
      messageSid,
      profileName,
      metadata: {
        error: error instanceof Error ? error.message : "unknown_error",
      },
    });

    return new NextResponse(twimlMessage(fallback), {
      status: 200,
      headers: {
        "Content-Type": "text/xml; charset=utf-8",
      },
    });
  }
}