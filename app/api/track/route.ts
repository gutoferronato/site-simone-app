import crypto from "node:crypto";
import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { prisma } from "@/lib/prisma";
import { checkRateLimit } from "@/lib/rate-limit";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const trackSchema = z.object({
  name: z.string().min(1).max(100),
  category: z.string().max(100).optional(),
  pageUrl: z.string().url().optional(),
  referrer: z.string().nullable().optional(),
  sessionId: z.string().min(1).max(100).optional(),
  anonymousId: z.string().min(1).max(100).optional(),
  utmSource: z.string().nullable().optional(),
  utmMedium: z.string().nullable().optional(),
  utmCampaign: z.string().nullable().optional(),
  utmContent: z.string().nullable().optional(),
  utmTerm: z.string().nullable().optional(),
  metadata: z.record(z.any()).optional(),
});

function hashIp(ip: string) {
  return crypto
    .createHash("sha256")
    .update(ip + (process.env.AUTH_SECRET ?? "simone"))
    .digest("hex");
}

export async function POST(request: NextRequest) {
  try {
    const ip =
      request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ??
      "0.0.0.0";

    const rate = checkRateLimit(`track:${ip}`, 120, 60_000);
    if (!rate.allowed) {
      return NextResponse.json({ error: "rate_limited" }, { status: 429 });
    }

    const parsed = trackSchema.safeParse(await request.json());
    if (!parsed.success) {
      return NextResponse.json({ error: "invalid_payload" }, { status: 400 });
    }

    const data = parsed.data;

    await prisma.pageEvent.create({
      data: {
        name: data.name,
        category: data.category,
        pageUrl: data.pageUrl,
        referrer: data.referrer ?? null,
        sessionId: data.sessionId,
        anonymousId: data.anonymousId,
        utmSource: data.utmSource ?? null,
        utmMedium: data.utmMedium ?? null,
        utmCampaign: data.utmCampaign ?? null,
        utmContent: data.utmContent ?? null,
        utmTerm: data.utmTerm ?? null,
        metadata: data.metadata,
        ipHash: hashIp(ip),
        userAgent: request.headers.get("user-agent"),
      },
    });

    return NextResponse.json({ ok: true });
  } catch (error) {
    return NextResponse.json(
      {
        error: error instanceof Error ? error.message : "track_failed",
      },
      { status: 500 }
    );
  }
}
