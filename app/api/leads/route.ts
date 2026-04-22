import { NextRequest, NextResponse } from "next/server";
import { InterestLevel } from "@prisma/client";
import { z } from "zod";
import { prisma } from "@/lib/prisma";
import { checkRateLimit } from "@/lib/rate-limit";
import { calculateLeadScore, scoreToStatus, scoreToTemperature } from "@/lib/score";
import { sendLeadNotification } from "@/lib/email";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const leadSchema = z.object({
  name: z.string().min(2).max(120),
  email: z.string().email().max(180),
  phone: z.string().min(8).max(30).optional().or(z.literal("")),
  instagram: z.string().max(60).optional().or(z.literal("")),
  message: z.string().max(1000).optional().or(z.literal("")),
  interestLevel: z.enum(["LOW", "MEDIUM", "HIGH"]).default("MEDIUM"),
  consentMarketing: z.boolean().default(false),
  consentAnalytics: z.boolean().default(true),
  anonymousId: z.string().min(1).max(100),
  sessionId: z.string().min(1).max(100),
  pageUrl: z.string().url().optional(),
  referrer: z.string().nullable().optional(),
  utmSource: z.string().nullable().optional(),
  utmMedium: z.string().nullable().optional(),
  utmCampaign: z.string().nullable().optional(),
  utmContent: z.string().nullable().optional(),
  utmTerm: z.string().nullable().optional(),
  honeypot: z.string().optional().or(z.literal("")),
});

export async function POST(request: NextRequest) {
  try {
    const ip =
      request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ??
      "0.0.0.0";

    const rate = checkRateLimit(`lead:${ip}`, 8, 15 * 60_000);
    if (!rate.allowed) {
      return NextResponse.json({ error: "rate_limited" }, { status: 429 });
    }

    const parsed = leadSchema.safeParse(await request.json());
    if (!parsed.success) {
      return NextResponse.json({ error: "invalid_payload" }, { status: 400 });
    }

    const data = parsed.data;

    if (data.honeypot) {
      return NextResponse.json({ ok: true });
    }

    const eventRows = await prisma.pageEvent.findMany({
      where: {
        OR: [
          { anonymousId: data.anonymousId },
          { sessionId: data.sessionId },
        ],
      },
      select: {
        name: true,
      },
      orderBy: {
        createdAt: "desc",
      },
      take: 100,
    });

    const score = calculateLeadScore({
      interestLevel: data.interestLevel as InterestLevel,
      eventNames: eventRows.map((item) => item.name),
    });

    const temperature = scoreToTemperature(score);
    const status = scoreToStatus(score);

    const lead = await prisma.lead.upsert({
      where: {
        email: data.email,
      },
      update: {
        name: data.name,
        phone: data.phone || null,
        instagram: data.instagram || null,
        interestLevel: data.interestLevel as InterestLevel,
        consentMarketing: data.consentMarketing,
        consentAnalytics: data.consentAnalytics,
        source: data.utmSource ?? "direct",
        utmSource: data.utmSource ?? null,
        utmMedium: data.utmMedium ?? null,
        utmCampaign: data.utmCampaign ?? null,
        utmContent: data.utmContent ?? null,
        utmTerm: data.utmTerm ?? null,
        score,
        temperature,
        status,
        notes: data.message || null,
        lastInteractionAt: new Date(),
      },
      create: {
        name: data.name,
        email: data.email,
        phone: data.phone || null,
        instagram: data.instagram || null,
        interestLevel: data.interestLevel as InterestLevel,
        consentMarketing: data.consentMarketing,
        consentAnalytics: data.consentAnalytics,
        source: data.utmSource ?? "direct",
        utmSource: data.utmSource ?? null,
        utmMedium: data.utmMedium ?? null,
        utmCampaign: data.utmCampaign ?? null,
        utmContent: data.utmContent ?? null,
        utmTerm: data.utmTerm ?? null,
        score,
        temperature,
        status,
        notes: data.message || null,
        firstSeenAt: new Date(),
        lastInteractionAt: new Date(),
      },
    });

    await prisma.pageEvent.updateMany({
      where: {
        leadId: null,
        OR: [
          { anonymousId: data.anonymousId },
          { sessionId: data.sessionId },
        ],
      },
      data: {
        leadId: lead.id,
      },
    });

    await prisma.pageEvent.create({
      data: {
        name: "lead_form_submit",
        category: "conversion",
        pageUrl: data.pageUrl ?? null,
        referrer: data.referrer ?? null,
        sessionId: data.sessionId,
        anonymousId: data.anonymousId,
        leadId: lead.id,
        utmSource: data.utmSource ?? null,
        utmMedium: data.utmMedium ?? null,
        utmCampaign: data.utmCampaign ?? null,
        utmContent: data.utmContent ?? null,
        utmTerm: data.utmTerm ?? null,
        metadata: {
          interestLevel: data.interestLevel,
          consentMarketing: data.consentMarketing,
        },
        userAgent: request.headers.get("user-agent"),
      },
    });

    await prisma.leadActivity.createMany({
      data: [
        {
          leadId: lead.id,
          type: "FORM_SUBMIT",
          summary: "Lead capturado pela landing page principal.",
          metadata: {
            pageUrl: data.pageUrl ?? null,
            message: data.message || null,
          },
        },
        {
          leadId: lead.id,
          type: "SCORE_UPDATED",
          summary: `Score recalculado para ${score}.`,
          metadata: {
            score,
            temperature,
            status,
          },
        },
      ],
    });

    void sendLeadNotification({
      id: lead.id,
      name: lead.name,
      email: lead.email,
      phone: lead.phone,
      score: lead.score,
      source: lead.source,
      temperature: lead.temperature,
    }).catch(() => {});

    return NextResponse.json({
      ok: true,
      leadId: lead.id,
      score: lead.score,
      temperature: lead.temperature,
      status: lead.status,
    });
  } catch (error) {
    return NextResponse.json(
      {
        error: error instanceof Error ? error.message : "lead_failed",
      },
      { status: 500 }
    );
  }
}
