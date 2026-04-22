$ErrorActionPreference = "Stop"

function Write-FileUtf8NoBom {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Content
  )

  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
  }

  $fullPath = Join-Path (Get-Location) $Path
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($fullPath, $Content, $utf8NoBom)
}

function Ensure-Command {
  param([string]$Name)
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Comando não encontrado: $Name"
  }
}

Ensure-Command "node"
Ensure-Command "npm"
Ensure-Command "npx"

$projectName = "simone-conversao-app"
$tempDir = "__next_bootstrap_temp__"

if (Test-Path ".\package.json") {
  throw "Já existe package.json nesta pasta. Rode este script em uma pasta limpa do projeto."
}

if (Test-Path ".\$tempDir") {
  Remove-Item -Recurse -Force ".\$tempDir"
}

Write-Host ">> Criando base Next.js..."
npx create-next-app@latest $tempDir --ts --tailwind --eslint --app --use-npm --import-alias "@/*" --yes

Write-Host ">> Movendo arquivos para a raiz..."
Get-ChildItem ".\$tempDir" -Force | ForEach-Object {
  Move-Item $_.FullName . -Force
}
Remove-Item -Recurse -Force ".\$tempDir"

Write-Host ">> Instalando dependências..."
npm install next-auth@beta @auth/prisma-adapter prisma @prisma/client zod react-hook-form @hookform/resolvers resend lru-cache clsx tailwind-merge lucide-react

Write-Host ">> Ajustando package.json..."
node -e @"
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('package.json','utf8'));
pkg.name = 'simone-conversao-app';
pkg.private = true;
pkg.scripts = {
  dev: 'next dev',
  build: 'next build',
  start: 'next start',
  lint: 'next lint',
  'db:generate': 'prisma generate',
  'db:push': 'prisma db push',
  'db:migrate': 'prisma migrate dev',
  'db:studio': 'prisma studio'
};
fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2));
"@

Write-Host ">> Criando pastas..."
$dirs = @(
  "app/api/auth/[...nextauth]",
  "app/api/track",
  "app/api/leads",
  "app/api/dashboard/summary",
  "app/api/health",
  "app/dashboard",
  "app/signin",
  "components/analytics",
  "components/forms",
  "components/layout",
  "components/ui",
  "lib",
  "prisma",
  "public"
)

foreach ($dir in $dirs) {
  New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

Write-Host ">> Escrevendo arquivos do sistema..."

Write-FileUtf8NoBom "next.config.ts" @'
import type { NextConfig } from "next";

const csp = `
  default-src 'self';
  script-src 'self' 'unsafe-inline' 'unsafe-eval';
  style-src 'self' 'unsafe-inline';
  img-src 'self' data: blob:;
  font-src 'self' data:;
  media-src 'self' blob:;
  connect-src 'self';
  base-uri 'self';
  form-action 'self' https://accounts.google.com;
  frame-ancestors 'none';
`.replace(/\s{2,}/g, " ").trim();

const nextConfig: NextConfig = {
  poweredByHeader: false,
  async headers() {
    return [
      {
        source: "/(.*)",
        headers: [
          { key: "Content-Security-Policy", value: csp },
          { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
          { key: "X-Content-Type-Options", value: "nosniff" },
          { key: "X-Frame-Options", value: "DENY" },
          { key: "X-DNS-Prefetch-Control", value: "off" },
          { key: "Permissions-Policy", value: "camera=(), microphone=(), geolocation=()" },
          { key: "Cross-Origin-Opener-Policy", value: "same-origin" },
        ],
      },
    ];
  },
};

export default nextConfig;
'@

Write-FileUtf8NoBom "middleware.ts" @'
import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
import { auth } from "@/auth";

export default auth((req) => {
  const isLoggedIn = !!req.auth;
  const pathname = req.nextUrl.pathname;

  if (pathname.startsWith("/dashboard") && !isLoggedIn) {
    const url = new URL("/signin", req.nextUrl.origin);
    url.searchParams.set("callbackUrl", req.nextUrl.href);
    return NextResponse.redirect(url);
  }

  return NextResponse.next();
});

export const config = {
  matcher: ["/dashboard/:path*"],
};
'@

Write-FileUtf8NoBom "auth.ts" @'
import NextAuth from "next-auth";
import Google from "next-auth/providers/google";
import { PrismaAdapter } from "@auth/prisma-adapter";
import { prisma } from "@/lib/prisma";

declare module "next-auth" {
  interface Session {
    user: {
      id: string;
      name?: string | null;
      email?: string | null;
      image?: string | null;
    };
  }
}

export const { handlers, auth, signIn, signOut } = NextAuth({
  adapter: PrismaAdapter(prisma),
  trustHost: true,
  session: {
    strategy: "jwt",
  },
  pages: {
    signIn: "/signin",
  },
  providers: [
    Google({
      clientId: process.env.AUTH_GOOGLE_ID ?? "",
      clientSecret: process.env.AUTH_GOOGLE_SECRET ?? "",
      allowDangerousEmailAccountLinking: true,
    }),
  ],
  callbacks: {
    async session({ session, token }) {
      if (session.user && token.sub) {
        session.user.id = token.sub;
      }
      return session;
    },
  },
  events: {
    async signIn({ user }) {
      if (!user.email || !user.id) return;

      await prisma.lead.updateMany({
        where: {
          email: user.email,
          userId: null,
        },
        data: {
          userId: user.id,
          lastInteractionAt: new Date(),
        },
      });
    },
  },
});
'@

Write-FileUtf8NoBom "prisma/schema.prisma" @'
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider  = "postgresql"
  url       = env("DATABASE_URL")
  directUrl = env("DIRECT_URL")
}

enum LeadStatus {
  NEW
  CONTACTED
  NURTURING
  QUALIFIED
  CONVERTED
  LOST
  UNSUBSCRIBED
  BLOCKED
}

enum LeadTemperature {
  COLD
  WARM
  HOT
}

enum InterestLevel {
  LOW
  MEDIUM
  HIGH
}

enum ActivityType {
  FORM_SUBMIT
  SCORE_UPDATED
  NOTE
  SYSTEM
}

model User {
  id            String    @id @default(cuid())
  name          String?
  email         String?   @unique
  emailVerified DateTime?
  image         String?
  accounts      Account[]
  sessions      Session[]
  lead          Lead?
  pageEvents    PageEvent[]
  createdAt     DateTime  @default(now())
  updatedAt     DateTime  @updatedAt
}

model Account {
  userId             String
  type               String
  provider           String
  providerAccountId  String
  refresh_token      String?
  access_token       String?
  expires_at         Int?
  token_type         String?
  scope              String?
  id_token           String?
  session_state      String?
  refresh_token_expires_in Int?

  user User @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@id([provider, providerAccountId])
}

model Session {
  sessionToken String   @unique
  userId       String
  expires      DateTime

  user User @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@id([sessionToken])
}

model VerificationToken {
  identifier String
  token      String
  expires    DateTime

  @@id([identifier, token])
}

model Lead {
  id                String           @id @default(cuid())
  name              String?
  email             String?          @unique
  phone             String?
  instagram         String?
  source            String?
  utmSource         String?
  utmMedium         String?
  utmCampaign       String?
  utmContent        String?
  utmTerm           String?
  status            LeadStatus       @default(NEW)
  temperature       LeadTemperature  @default(COLD)
  interestLevel     InterestLevel    @default(LOW)
  score             Int              @default(0)
  notes             String?
  owner             String?
  consentAnalytics  Boolean          @default(true)
  consentMarketing  Boolean          @default(false)
  firstSeenAt       DateTime         @default(now())
  lastInteractionAt DateTime?
  nextFollowupAt    DateTime?
  userId            String?          @unique
  user              User?            @relation(fields: [userId], references: [id], onDelete: SetNull)
  pageEvents        PageEvent[]
  activities        LeadActivity[]
  createdAt         DateTime         @default(now())
  updatedAt         DateTime         @updatedAt

  @@index([status])
  @@index([temperature])
  @@index([score])
  @@index([createdAt])
  @@index([utmSource, utmMedium, utmCampaign])
}

model PageEvent {
  id          String   @id @default(cuid())
  name        String
  category    String?
  pageUrl     String?
  referrer    String?
  sessionId   String?
  anonymousId String?
  leadId      String?
  userId      String?
  ipHash      String?
  userAgent   String?
  utmSource   String?
  utmMedium   String?
  utmCampaign String?
  utmContent  String?
  utmTerm     String?
  metadata    Json?
  createdAt   DateTime @default(now())

  lead Lead? @relation(fields: [leadId], references: [id], onDelete: SetNull)
  user User? @relation(fields: [userId], references: [id], onDelete: SetNull)

  @@index([name, createdAt])
  @@index([leadId, createdAt])
  @@index([anonymousId, createdAt])
  @@index([sessionId, createdAt])
}

model LeadActivity {
  id        String       @id @default(cuid())
  leadId    String
  type      ActivityType
  summary   String
  metadata  Json?
  createdAt DateTime     @default(now())

  lead Lead @relation(fields: [leadId], references: [id], onDelete: Cascade)

  @@index([leadId, createdAt])
}
'@

Write-FileUtf8NoBom "lib/prisma.ts" @'
import { PrismaClient } from "@prisma/client";

const globalForPrisma = globalThis as unknown as {
  prisma?: PrismaClient;
};

export const prisma =
  globalForPrisma.prisma ??
  new PrismaClient({
    log: process.env.NODE_ENV === "development" ? ["error", "warn"] : ["error"],
  });

if (process.env.NODE_ENV !== "production") globalForPrisma.prisma = prisma;
'@

Write-FileUtf8NoBom "lib/env.ts" @'
import { z } from "zod";

const envSchema = z.object({
  NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
  DATABASE_URL: z.string().min(1),
  DIRECT_URL: z.string().min(1),
  AUTH_SECRET: z.string().min(1),
  AUTH_GOOGLE_ID: z.string().min(1),
  AUTH_GOOGLE_SECRET: z.string().min(1),
  NEXT_PUBLIC_APP_URL: z.string().url(),
  NEXT_PUBLIC_SITE_NAME: z.string().default("Simone Matos"),
  NEXT_PUBLIC_WHATSAPP_URL: z.string().url().default("https://wa.me/5500000000000"),
  RESEND_API_KEY: z.string().optional(),
  RESEND_FROM: z.string().optional(),
  SALES_NOTIFICATION_EMAIL: z.string().optional(),
});

export const env = envSchema.parse({
  NODE_ENV: process.env.NODE_ENV,
  DATABASE_URL: process.env.DATABASE_URL,
  DIRECT_URL: process.env.DIRECT_URL,
  AUTH_SECRET: process.env.AUTH_SECRET,
  AUTH_GOOGLE_ID: process.env.AUTH_GOOGLE_ID,
  AUTH_GOOGLE_SECRET: process.env.AUTH_GOOGLE_SECRET,
  NEXT_PUBLIC_APP_URL: process.env.NEXT_PUBLIC_APP_URL,
  NEXT_PUBLIC_SITE_NAME: process.env.NEXT_PUBLIC_SITE_NAME,
  NEXT_PUBLIC_WHATSAPP_URL: process.env.NEXT_PUBLIC_WHATSAPP_URL,
  RESEND_API_KEY: process.env.RESEND_API_KEY,
  RESEND_FROM: process.env.RESEND_FROM,
  SALES_NOTIFICATION_EMAIL: process.env.SALES_NOTIFICATION_EMAIL,
});
'@

Write-FileUtf8NoBom "lib/utils.ts" @'
import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function formatDate(date: Date | string) {
  return new Intl.DateTimeFormat("pt-BR", {
    dateStyle: "short",
    timeStyle: "short",
  }).format(new Date(date));
}
'@

Write-FileUtf8NoBom "lib/rate-limit.ts" @'
import { LRUCache } from "lru-cache";

type Entry = {
  count: number;
  resetAt: number;
};

const globalForRateLimit = globalThis as unknown as {
  limiter?: LRUCache<string, Entry>;
};

const limiter =
  globalForRateLimit.limiter ??
  new LRUCache<string, Entry>({
    max: 10000,
    ttl: 1000 * 60 * 10,
  });

if (process.env.NODE_ENV !== "production") {
  globalForRateLimit.limiter = limiter;
}

export function checkRateLimit(key: string, limit = 20, windowMs = 60_000) {
  const now = Date.now();
  const existing = limiter.get(key);

  if (!existing || existing.resetAt <= now) {
    limiter.set(key, { count: 1, resetAt: now + windowMs }, { ttl: windowMs });
    return { allowed: true, remaining: limit - 1, resetAt: now + windowMs };
  }

  if (existing.count >= limit) {
    return { allowed: false, remaining: 0, resetAt: existing.resetAt };
  }

  existing.count += 1;
  limiter.set(key, existing, { ttl: existing.resetAt - now });

  return {
    allowed: true,
    remaining: Math.max(0, limit - existing.count),
    resetAt: existing.resetAt,
  };
}
'@

Write-FileUtf8NoBom "lib/score.ts" @'
import { InterestLevel, LeadStatus, LeadTemperature } from "@prisma/client";

type ScoreInput = {
  interestLevel: InterestLevel;
  eventNames: string[];
};

const eventWeights: Record<string, number> = {
  page_view: 2,
  hero_cta_click: 12,
  mock_link_click: 10,
  whatsapp_click: 20,
  email_click: 8,
  lead_form_open: 10,
  lead_form_submit: 25,
};

const interestWeights: Record<InterestLevel, number> = {
  LOW: 8,
  MEDIUM: 18,
  HIGH: 32,
};

export function calculateLeadScore(input: ScoreInput) {
  const { interestLevel, eventNames } = input;

  const pageViews = eventNames.filter((name) => name === "page_view").length;
  const uniqueEvents = new Set(eventNames);

  let score = interestWeights[interestLevel];
  score += Math.min(pageViews * 3, 15);

  for (const eventName of uniqueEvents) {
    if (eventName === "page_view") continue;
    score += eventWeights[eventName] ?? 0;
  }

  return Math.min(score, 100);
}

export function scoreToTemperature(score: number): LeadTemperature {
  if (score >= 65) return "HOT";
  if (score >= 35) return "WARM";
  return "COLD";
}

export function scoreToStatus(score: number): LeadStatus {
  if (score >= 65) return "QUALIFIED";
  if (score >= 35) return "NURTURING";
  return "NEW";
}
'@

Write-FileUtf8NoBom "lib/tracking.ts" @'
"use client";

type TrackPayload = {
  name: string;
  category?: string;
  pageUrl?: string;
  referrer?: string | null;
  sessionId?: string;
  anonymousId?: string;
  utmSource?: string | null;
  utmMedium?: string | null;
  utmCampaign?: string | null;
  utmContent?: string | null;
  utmTerm?: string | null;
  metadata?: Record<string, unknown>;
};

const ANON_KEY = "sc_anon_id";
const SESSION_KEY = "sc_session_id";
const UTM_KEY = "sc_utm";

export function getOrCreateAnonymousId() {
  if (typeof window === "undefined") return "";
  let id = localStorage.getItem(ANON_KEY);
  if (!id) {
    id = crypto.randomUUID();
    localStorage.setItem(ANON_KEY, id);
  }
  return id;
}

export function getOrCreateSessionId() {
  if (typeof window === "undefined") return "";
  let id = sessionStorage.getItem(SESSION_KEY);
  if (!id) {
    id = crypto.randomUUID();
    sessionStorage.setItem(SESSION_KEY, id);
  }
  return id;
}

export function captureUtms() {
  if (typeof window === "undefined") return;

  const url = new URL(window.location.href);
  const data = {
    utmSource: url.searchParams.get("utm_source"),
    utmMedium: url.searchParams.get("utm_medium"),
    utmCampaign: url.searchParams.get("utm_campaign"),
    utmContent: url.searchParams.get("utm_content"),
    utmTerm: url.searchParams.get("utm_term"),
  };

  const hasAny = Object.values(data).some(Boolean);
  if (hasAny) {
    localStorage.setItem(UTM_KEY, JSON.stringify(data));
  }
}

export function getStoredUtms() {
  if (typeof window === "undefined") {
    return {
      utmSource: null,
      utmMedium: null,
      utmCampaign: null,
      utmContent: null,
      utmTerm: null,
    };
  }

  const raw = localStorage.getItem(UTM_KEY);
  if (!raw) {
    return {
      utmSource: null,
      utmMedium: null,
      utmCampaign: null,
      utmContent: null,
      utmTerm: null,
    };
  }

  try {
    return JSON.parse(raw);
  } catch {
    return {
      utmSource: null,
      utmMedium: null,
      utmCampaign: null,
      utmContent: null,
      utmTerm: null,
    };
  }
}

export function getClientContext() {
  captureUtms();

  return {
    pageUrl: typeof window !== "undefined" ? window.location.href : "",
    referrer: typeof document !== "undefined" ? document.referrer || null : null,
    anonymousId: getOrCreateAnonymousId(),
    sessionId: getOrCreateSessionId(),
    ...getStoredUtms(),
  };
}

export function trackEvent(payload: TrackPayload) {
  if (typeof window === "undefined") return;

  const body = JSON.stringify({
    ...getClientContext(),
    ...payload,
    pageUrl: payload.pageUrl ?? window.location.href,
    referrer: payload.referrer ?? document.referrer || null,
  });

  const blob = new Blob([body], { type: "application/json" });

  if (navigator.sendBeacon) {
    navigator.sendBeacon("/api/track", blob);
    return;
  }

  void fetch("/api/track", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body,
    keepalive: true,
  });
}
'@

Write-FileUtf8NoBom "lib/email.ts" @'
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
'@

Write-FileUtf8NoBom "app/api/auth/[...nextauth]/route.ts" @'
import { handlers } from "@/auth";

export const { GET, POST } = handlers;
'@

Write-FileUtf8NoBom "app/api/health/route.ts" @'
import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET() {
  try {
    await prisma.$queryRaw`SELECT 1`;

    return NextResponse.json({
      ok: true,
      service: "simone-conversao-app",
      database: "up",
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    return NextResponse.json(
      {
        ok: false,
        database: "down",
        error: error instanceof Error ? error.message : "unknown_error",
      },
      { status: 500 }
    );
  }
}
'@

Write-FileUtf8NoBom "app/api/track/route.ts" @'
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
'@

Write-FileUtf8NoBom "app/api/leads/route.ts" @'
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
'@

Write-FileUtf8NoBom "app/api/dashboard/summary/route.ts" @'
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
'@

Write-FileUtf8NoBom "components/layout/Header.tsx" @'
import Image from "next/image";
import Link from "next/link";
import { auth, signOut } from "@/auth";

export async function Header() {
  const session = await auth();

  return (
    <header className="sticky top-0 z-40 border-b border-white/10 bg-[#41050a]/70 backdrop-blur-xl">
      <div className="mx-auto flex max-w-6xl items-center justify-between px-4 py-4 md:px-6">
        <Link href="/" className="flex items-center gap-3">
          <Image
            src="/logo-sm.svg"
            alt="Simone Matos"
            width={48}
            height={48}
            className="h-12 w-12"
            priority
          />
          <div className="leading-tight">
            <p className="font-serif text-lg text-[#f3c15d]">Simone Matos</p>
            <p className="text-xs uppercase tracking-[0.25em] text-white/60">
              Super Conversão
            </p>
          </div>
        </Link>

        <nav className="hidden items-center gap-6 text-sm text-white/80 md:flex">
          <a href="#hero" className="transition hover:text-[#f3c15d]">Início</a>
          <a href="#links" className="transition hover:text-[#f3c15d]">Links</a>
          <a href="#captura" className="transition hover:text-[#f3c15d]">Contato</a>
          <Link href="/dashboard" className="transition hover:text-[#f3c15d]">
            Dashboard
          </Link>
        </nav>

        <div className="flex items-center gap-3">
          {session?.user ? (
            <form
              action={async () => {
                "use server";
                await signOut({ redirectTo: "/" });
              }}
            >
              <button
                className="rounded-full border border-[#f3c15d]/40 px-4 py-2 text-sm text-[#f3c15d] transition hover:bg-[#f3c15d]/10"
                type="submit"
              >
                Sair
              </button>
            </form>
          ) : (
            <Link
              href="/signin"
              className="rounded-full bg-[#f3c15d] px-4 py-2 text-sm font-medium text-[#3a0509] transition hover:opacity-90"
            >
              Entrar com Google
            </Link>
          )}
        </div>
      </div>
    </header>
  );
}
'@

Write-FileUtf8NoBom "components/analytics/PageViewTracker.tsx" @'
"use client";

import { useEffect } from "react";
import { trackEvent } from "@/lib/tracking";

export function PageViewTracker() {
  useEffect(() => {
    trackEvent({
      name: "page_view",
      category: "navigation",
      metadata: {
        title: document.title,
      },
    });
  }, []);

  return null;
}
'@

Write-FileUtf8NoBom "components/analytics/TrackedLink.tsx" @'
"use client";

import Link from "next/link";
import { trackEvent } from "@/lib/tracking";
import { cn } from "@/lib/utils";

type TrackedLinkProps = {
  href: string;
  title: string;
  description: string;
  eventLabel: string;
  className?: string;
};

export function TrackedLink({
  href,
  title,
  description,
  eventLabel,
  className,
}: TrackedLinkProps) {
  return (
    <Link
      href={href}
      className={cn(
        "group relative overflow-hidden rounded-[28px] border border-white/10 bg-white/5 p-5 shadow-[0_20px_60px_-30px_rgba(0,0,0,0.9)] backdrop-blur-md transition duration-300 hover:-translate-y-1 hover:border-[#f3c15d]/50 hover:bg-white/10",
        className
      )}
      onClick={() => {
        trackEvent({
          name: "mock_link_click",
          category: "engagement",
          metadata: {
            label: eventLabel,
            href,
          },
        });
      }}
    >
      <div className="absolute inset-0 bg-[radial-gradient(circle_at_top,rgba(243,193,93,0.14),transparent_55%)] opacity-0 transition group-hover:opacity-100" />
      <div className="relative">
        <p className="mb-2 text-xs font-semibold uppercase tracking-[0.25em] text-[#f3c15d]/85">
          Link estratégico
        </p>
        <h3 className="mb-2 text-xl font-semibold text-white">{title}</h3>
        <p className="text-sm leading-6 text-white/70">{description}</p>
      </div>
    </Link>
  );
}
'@

Write-FileUtf8NoBom "components/Hero.tsx" @'
import Image from "next/image";
import { ArrowDownRight, PlayCircle } from "lucide-react";

export function Hero() {
  return (
    <section id="hero" className="relative overflow-hidden">
      <div className="absolute inset-0 bg-[radial-gradient(circle_at_top,rgba(243,193,93,0.14),transparent_40%),radial-gradient(circle_at_bottom,rgba(255,255,255,0.07),transparent_30%)]" />
      <div className="relative mx-auto grid max-w-6xl items-center gap-10 px-4 py-14 md:px-6 md:py-24 lg:grid-cols-[1.1fr_0.9fr]">
        <div className="max-w-2xl">
          <div className="mb-6 inline-flex items-center gap-3 rounded-full border border-[#f3c15d]/25 bg-white/5 px-4 py-2 text-sm text-[#f8d58a] backdrop-blur">
            <Image
              src="/logo-sm.svg"
              alt="Logotipo Simone Matos"
              width={28}
              height={28}
              className="h-7 w-7"
            />
            Linktree premium com infraestrutura de CRM, tracking e conversão
          </div>

          <h1 className="max-w-3xl font-serif text-4xl leading-tight text-white md:text-6xl">
            Uma página elegante por fora.
            <span className="block text-[#f3c15d]">
              Uma máquina de conversão por trás.
            </span>
          </h1>

          <p className="mt-6 max-w-2xl text-base leading-8 text-white/75 md:text-lg">
            Este projeto já nasce com captura de leads, score de interesse, login com Google,
            rastreamento de comportamento, APIs seguras e base preparada para expandir para
            novas páginas sem perder a inteligência do sistema.
          </p>

          <div className="mt-8 flex flex-col gap-3 sm:flex-row">
            <a
              href="#links"
              className="inline-flex items-center justify-center gap-2 rounded-full bg-[#f3c15d] px-6 py-3 font-medium text-[#3a0509] transition hover:opacity-90"
            >
              Ver links estratégicos
              <ArrowDownRight className="h-4 w-4" />
            </a>
            <a
              href="#captura"
              className="inline-flex items-center justify-center gap-2 rounded-full border border-white/15 bg-white/5 px-6 py-3 font-medium text-white transition hover:bg-white/10"
            >
              Capturar lead de teste
              <PlayCircle className="h-4 w-4" />
            </a>
          </div>
        </div>

        <div className="relative">
          <div className="overflow-hidden rounded-[32px] border border-white/10 bg-[#190204] shadow-[0_30px_80px_-35px_rgba(0,0,0,1)]">
            <div className="relative aspect-[10/12] w-full bg-[linear-gradient(180deg,rgba(0,0,0,0.1),rgba(58,5,9,0.4)),radial-gradient(circle_at_top,rgba(243,193,93,0.24),transparent_40%),linear-gradient(135deg,#1a0204,#5b0710,#2d0408)]">
              <video
                className="absolute inset-0 h-full w-full object-cover opacity-50"
                src="/video-secao-hero.mp4"
                autoPlay
                muted
                loop
                playsInline
                preload="metadata"
              />
              <div className="absolute inset-0 bg-gradient-to-t from-[#120103] via-[#120103]/40 to-transparent" />
              <div className="absolute inset-x-0 bottom-0 p-8">
                <div className="mb-4 inline-flex items-center rounded-full border border-[#f3c15d]/30 bg-black/30 px-3 py-1 text-xs uppercase tracking-[0.25em] text-[#f3c15d] backdrop-blur">
                  vídeo hero substituível
                </div>
                <h2 className="max-w-md font-serif text-3xl leading-tight text-white">
                  Troque o arquivo <span className="text-[#f3c15d]">video-secao-hero.mp4</span> pelo seu vídeo.
                </h2>
                <p className="mt-3 max-w-md text-sm leading-7 text-white/70">
                  Enquanto isso, a seção já está pronta com design premium, overlay elegante e CTA
                  rastreável para capturar comportamento e intenção.
                </p>
              </div>
            </div>
          </div>

          <div className="absolute -bottom-5 -left-5 hidden rounded-3xl border border-[#f3c15d]/25 bg-[#5a0910]/70 px-5 py-4 shadow-xl backdrop-blur md:block">
            <p className="text-xs uppercase tracking-[0.25em] text-[#f3c15d]">tracking ativo</p>
            <p className="mt-1 text-lg font-semibold text-white">page_view • click • lead</p>
          </div>
        </div>
      </div>
    </section>
  );
}
'@

Write-FileUtf8NoBom "components/forms/LeadCaptureForm.tsx" @'
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
        <p className="text-xs font-semibold uppercase tracking-[0.3em] text-[#f3c15d]">
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
            className="rounded-2xl border border-white/10 bg-[#210306] px-4 py-3 text-white outline-none ring-0 transition placeholder:text-white/35 focus:border-[#f3c15d]/50"
            placeholder="Seu nome"
            {...form.register("name", { required: true, minLength: 2 })}
          />
        </label>

        <label className="grid gap-2">
          <span className="text-sm text-white/75">E-mail</span>
          <input
            type="email"
            className="rounded-2xl border border-white/10 bg-[#210306] px-4 py-3 text-white outline-none transition placeholder:text-white/35 focus:border-[#f3c15d]/50"
            placeholder="voce@email.com"
            {...form.register("email", { required: true })}
          />
        </label>

        <label className="grid gap-2">
          <span className="text-sm text-white/75">WhatsApp</span>
          <input
            className="rounded-2xl border border-white/10 bg-[#210306] px-4 py-3 text-white outline-none transition placeholder:text-white/35 focus:border-[#f3c15d]/50"
            placeholder="(00) 00000-0000"
            {...form.register("phone")}
          />
        </label>

        <label className="grid gap-2">
          <span className="text-sm text-white/75">Instagram</span>
          <input
            className="rounded-2xl border border-white/10 bg-[#210306] px-4 py-3 text-white outline-none transition placeholder:text-white/35 focus:border-[#f3c15d]/50"
            placeholder="@seuinstagram"
            {...form.register("instagram")}
          />
        </label>

        <label className="grid gap-2 md:col-span-2">
          <span className="text-sm text-white/75">Nível de interesse</span>
          <select
            className="rounded-2xl border border-white/10 bg-[#210306] px-4 py-3 text-white outline-none transition focus:border-[#f3c15d]/50"
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
            className="rounded-2xl border border-white/10 bg-[#210306] px-4 py-3 text-white outline-none transition placeholder:text-white/35 focus:border-[#f3c15d]/50"
            placeholder="Conte um pouco do que você busca."
            {...form.register("message")}
          />
        </label>

        <label className="md:col-span-2 flex items-start gap-3 rounded-2xl border border-white/10 bg-[#210306]/80 p-4 text-sm text-white/70">
          <input
            type="checkbox"
            className="mt-1 h-4 w-4 accent-[#f3c15d]"
            {...form.register("consentMarketing")}
          />
          Aceito receber comunicações úteis e canceláveis por e-mail.
        </label>

        <div className="md:col-span-2 flex flex-col gap-3 sm:flex-row sm:items-center">
          <button
            type="submit"
            disabled={isSubmitting}
            className="inline-flex items-center justify-center rounded-full bg-[#f3c15d] px-6 py-3 font-medium text-[#3a0509] transition hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-60"
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
'@

Write-FileUtf8NoBom "app/layout.tsx" @'
import type { Metadata } from "next";
import { Inter, Cormorant_Garamond } from "next/font/google";
import "./globals.css";
import { Header } from "@/components/layout/Header";
import { PageViewTracker } from "@/components/analytics/PageViewTracker";

const inter = Inter({
  subsets: ["latin"],
  variable: "--font-inter",
});

const cormorant = Cormorant_Garamond({
  subsets: ["latin"],
  variable: "--font-serif",
  weight: ["400", "500", "600", "700"],
});

export const metadata: Metadata = {
  title: "Simone Matos • Super Conversão",
  description:
    "Linktree premium com infraestrutura de login Google, tracking, CRM, lead scoring e APIs em Next.js.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="pt-BR">
      <body className={`${inter.variable} ${cormorant.variable} bg-[#5b0710] text-white antialiased`}>
        <div className="min-h-screen bg-[linear-gradient(180deg,#5b0710_0%,#43050a_35%,#2a0206_100%)]">
          <Header />
          <PageViewTracker />
          {children}
        </div>
      </body>
    </html>
  );
}
'@

Write-FileUtf8NoBom "app/page.tsx" @'
import { Hero } from "@/components/Hero";
import { TrackedLink } from "@/components/analytics/TrackedLink";
import { LeadCaptureForm } from "@/components/forms/LeadCaptureForm";

export default function HomePage() {
  return (
    <main>
      <Hero />

      <section id="links" className="mx-auto max-w-6xl px-4 py-8 md:px-6 md:py-14">
        <div className="mb-10 text-center">
          <p className="text-xs font-semibold uppercase tracking-[0.3em] text-[#f3c15d]">
            linktree estratégico
          </p>
          <h2 className="mt-4 font-serif text-4xl text-white md:text-5xl">
            Três links mock-up para apresentar o trabalho
          </h2>
          <p className="mx-auto mt-4 max-w-3xl text-sm leading-7 text-white/70 md:text-base">
            Cada clique já passa pelo rastreamento do sistema. Esta primeira página foi desenhada
            para funcionar como Linktree premium, mas com base real de CRM e analytics por trás.
          </p>
        </div>

        <div className="grid gap-5 md:grid-cols-3">
          <TrackedLink
            href="#captura"
            eventLabel="processo-terapeutico"
            title="Processo terapêutico premium"
            description="Uma jornada profunda para mulheres que querem reorganizar autoestima, desejo, merecimento e posicionamento emocional."
          />
          <TrackedLink
            href="#captura"
            eventLabel="jornada-autoestima"
            title="Jornada de autoestima e sexualidade"
            description="Um link mock-up para apresentar a principal transformação: sair da repetição emocional e voltar a sentir valor em si."
          />
          <TrackedLink
            href="/signin"
            eventLabel="area-admin"
            title="Área estratégica e acompanhamento"
            description="Link mock-up para mostrar que o projeto também se conecta com área interna, dashboard e leitura dos sinais de intenção."
          />
        </div>
      </section>

      <section className="mx-auto grid max-w-6xl gap-8 px-4 py-6 md:px-6 md:grid-cols-[0.9fr_1.1fr] md:py-10">
        <div className="rounded-[32px] border border-white/10 bg-white/5 p-6 backdrop-blur md:p-8">
          <p className="text-xs font-semibold uppercase tracking-[0.3em] text-[#f3c15d]">
            manifesto
          </p>
          <h3 className="mt-3 font-serif text-3xl text-white">
            Design elevado, backend completo e decisão orientada por dados.
          </h3>
          <div className="mt-4 space-y-4 text-sm leading-7 text-white/72">
            <p>
              Esta página não é só vitrine. Ela já nasce com captura de UTMs, eventos, rastreamento
              de cliques, proteção contra abuso, login com Google e estrutura de APIs pronta.
            </p>
            <p>
              Quando você pedir uma nova página, a base do sistema já está pronta para repetir a
              mesma infraestrutura: comportamento, lead, score, consentimento e leitura de jornada.
            </p>
            <p>
              O visual foi refinado para parecer premium desde a primeira visita: vinho profundo,
              dourado elegante, vidro fosco, tipografia editorial e foco total em conversão.
            </p>
          </div>
        </div>

        <LeadCaptureForm />
      </section>

      <footer className="mx-auto max-w-6xl px-4 py-12 text-center text-sm text-white/50 md:px-6">
        Simone Matos • Linktree premium com infraestrutura de conversão, CRM e rastreamento.
      </footer>
    </main>
  );
}
'@

Write-FileUtf8NoBom "app/signin/page.tsx" @'
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
            className="w-full rounded-full bg-[#f3c15d] px-5 py-3 font-medium text-[#3a0509] transition hover:opacity-90"
          >
            Continuar com Google
          </button>
        </form>
      </div>
    </main>
  );
}
'@

Write-FileUtf8NoBom "app/dashboard/page.tsx" @'
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
      <p className="text-xs font-semibold uppercase tracking-[0.25em] text-[#f3c15d]">{title}</p>
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
        <p className="text-xs font-semibold uppercase tracking-[0.3em] text-[#f3c15d]">
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
'@

Write-FileUtf8NoBom "app/globals.css" @'
@import "tailwindcss";

:root {
  --background: #2d0408;
  --foreground: #ffffff;
}

html {
  scroll-behavior: smooth;
}

body {
  background: var(--background);
  color: var(--foreground);
  font-family: var(--font-inter), Arial, Helvetica, sans-serif;
}

.font-serif {
  font-family: var(--font-serif), Georgia, serif;
}

::selection {
  background: rgba(243, 193, 93, 0.3);
  color: #fff;
}

input,
select,
textarea,
button {
  font: inherit;
}
'@

Write-FileUtf8NoBom ".env.example" @'
# =========================
# APP
# =========================
NEXT_PUBLIC_APP_URL=http://localhost:3000
NEXT_PUBLIC_SITE_NAME=Simone Matos
NEXT_PUBLIC_WHATSAPP_URL=https://wa.me/5500000000000

# =========================
# AUTH
# =========================
AUTH_SECRET=gere_um_secret_forte_aqui
AUTH_GOOGLE_ID=coloque_o_google_client_id
AUTH_GOOGLE_SECRET=coloque_o_google_client_secret

# =========================
# SUPABASE / POSTGRES
# DATABASE_URL -> pooled connection
# DIRECT_URL -> direct connection
# =========================
DATABASE_URL=postgresql://postgres.xxxxx:[PASSWORD]@aws-0-us-east-1.pooler.supabase.com:6543/postgres?pgbouncer=true&connection_limit=1
DIRECT_URL=postgresql://postgres:[PASSWORD]@db.xxxxx.supabase.co:5432/postgres

# =========================
# EMAIL (OPCIONAL)
# =========================
RESEND_API_KEY=
RESEND_FROM=
SALES_NOTIFICATION_EMAIL=
"@

Write-FileUtf8NoBom "README.md" @"
# Simone Conversão App

## O que já vem pronto
- Next.js App Router
- Login com Google via Auth.js
- Prisma + Supabase Postgres
- Tracking de eventos
- CRM básico com score e temperatura
- Dashboard protegido
- Rate limiting, honeypot e headers de segurança
- Estrutura pronta para novas páginas com o mesmo backend

## Setup
1. Copie `.env.example` para `.env`
2. Preencha as variáveis
3. Rode:

```bash
npm install
npx prisma generate
npx prisma db push
npm run dev