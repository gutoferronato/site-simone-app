import { NextResponse } from "next/server";
import { auth } from "@/auth";
import { prisma } from "@/lib/prisma";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET() {
  const session = await auth();

  if (!session?.user) {
    return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  }

  const [totalLeads, hotLeads, warmLeads, totalEvents, latestLeads] = await Promise.all([
    prisma.lead.count(),
    prisma.lead.count({ where: { temperature: "HOT" } }),
    prisma.lead.count({ where: { temperature: "WARM" } }),
    prisma.pageEvent.count(),
    prisma.lead.findMany({
      take: 5,
      orderBy: { createdAt: "desc" },
      select: {
        id: true,
        name: true,
        email: true,
        score: true,
        temperature: true,
        createdAt: true,
      },
    }),
  ]);

  return NextResponse.json({
    totalLeads,
    hotLeads,
    warmLeads,
    totalEvents,
    latestLeads,
  });
}
