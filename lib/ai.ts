type GenerateAIAnswerInput = {
  systemPrompt: string;
  userMessage: string;
};

type GeminiResponse = {
  candidates?: Array<{
    content?: {
      parts?: Array<{
        text?: string;
      }>;
    };
  }>;
  error?: {
    message?: string;
  };
};

export async function generateAIAnswer({
  systemPrompt,
  userMessage,
}: GenerateAIAnswerInput) {
  const apiKey = process.env.GEMINI_API_KEY;

  if (!apiKey) {
    throw new Error("GEMINI_API_KEY não configurada.");
  }

  const model = process.env.GEMINI_MODEL || "gemini-2.5-flash-lite";

  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        systemInstruction: {
          parts: [{ text: systemPrompt }],
        },
        contents: [
          {
            role: "user",
            parts: [{ text: userMessage }],
          },
        ],
        generationConfig: {
          temperature: 0.3,
          maxOutputTokens: 350,
        },
      }),
    }
  );

  const data = (await response.json()) as GeminiResponse;

  if (!response.ok) {
    throw new Error(
      data.error?.message || `Erro Gemini API: ${response.status}`
    );
  }

  const text = data.candidates?.[0]?.content?.parts?.[0]?.text?.trim();

  return (
    text ||
    "Não consegui responder com segurança agora. Pode reformular sua dúvida?"
  );
}