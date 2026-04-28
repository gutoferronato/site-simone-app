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

function getClientIp(req: NextRequest) {
  return (
    req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ||
    req.headers.get("x-real-ip") ||
    "unknown"
  );
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
  } catch {
    // Não derruba o webhook se o banco falhar.
  }
}

function validateTwilioSignature({
  req,
  rawBody,
}: {
  req: NextRequest;
  rawBody: string;
}) {
  const shouldValidate = process.env.TWILIO_VALIDATE_SIGNATURE !== "false";

  if (!shouldValidate) return true;

  const authToken = process.env.TWILIO_AUTH_TOKEN;
  const publicUrl = process.env.TWILIO_WEBHOOK_PUBLIC_URL;

  if (!authToken || !publicUrl) {
    return false;
  }

  const signature = req.headers.get("x-twilio-signature");

  if (!signature) {
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
    metadata: {
      ip: getClientIp(req),
    },
  });

  try {
    const result = await answerWhatsAppMessage({
      userMessage: body,
      userPhone: from,
      userName: profileName,
    });

    await recordWhatsAppEvent({
      name: "whatsapp_message_replied",
      from,
      body: result.reply,
      messageSid,
      profileName,
      metadata: {
        shouldHandoff: result.shouldHandoff,
        reason: result.reason,
      },
    });

    return new NextResponse(twimlMessage(result.reply), {
      status: 200,
      headers: {
        "Content-Type": "text/xml; charset=utf-8",
      },
    });
  } catch {
    const fallback =
      process.env.HUMAN_HANDOFF_MESSAGE ||
      "Tive uma instabilidade aqui. Vou encaminhar para atendimento humano te responder com segurança.";

    await recordWhatsAppEvent({
      name: "whatsapp_bot_error",
      from,
      body,
      messageSid,
      profileName,
    });

    return new NextResponse(twimlMessage(fallback), {
      status: 200,
      headers: {
        "Content-Type": "text/xml; charset=utf-8",
      },
    });
  }
}