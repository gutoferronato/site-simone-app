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
