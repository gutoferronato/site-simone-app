import OpenAI from "openai";

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

type GenerateAIAnswerInput = {
  systemPrompt: string;
  userMessage: string;
};

export async function generateAIAnswer({
  systemPrompt,
  userMessage,
}: GenerateAIAnswerInput) {
  if (!process.env.OPENAI_API_KEY) {
    throw new Error("OPENAI_API_KEY não configurada.");
  }

  const response = await openai.chat.completions.create({
    model: process.env.OPENAI_MODEL || "gpt-4o-mini",
    temperature: 0.3,
    max_tokens: 350,
    messages: [
      {
        role: "system",
        content: systemPrompt,
      },
      {
        role: "user",
        content: userMessage,
      },
    ],
  });

  return (
    response.choices[0]?.message?.content?.trim() ||
    "Não consegui responder com segurança agora. Vou encaminhar para atendimento humano."
  );
}