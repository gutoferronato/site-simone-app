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
    referrer: payload.referrer ?? (document.referrer || null),
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
