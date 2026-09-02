// Delivery-note OCR for the WMS mobile client.
// POST /ocr-delivery-note  (multipart/form-data: image, provider?, plan_id?)
// -> { data: { provider, lines: [{ jan_code, product_name, quantity }] } }
//
// Priority provider = Gemini (key stays server-side). Qwen is a reserved slot.
// Requires the GEMINI_API_KEY secret:  supabase secrets set GEMINI_API_KEY=...
import { encodeBase64 } from "jsr:@std/encoding/base64";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

const PROMPT =
  "あなたは日本の物流の納品書を読み取るアシスタントです。この画像の明細表を" +
  "抽出し、各行を {jan_code, product_name, quantity} のJSONで返してください。" +
  "jan_code は商品のバーコード数字（13桁または8桁）のみ。住所・電話番号・" +
  "登録番号(Tで始まる番号)・合計金額などはJANとして扱わないこと。数量が読めない" +
  "行は quantity を省略。表に無い行は返さないこと。";

const SCHEMA = {
  type: "object",
  properties: {
    lines: {
      type: "array",
      items: {
        type: "object",
        properties: {
          jan_code: { type: "string" },
          product_name: { type: "string" },
          quantity: { type: "integer" },
        },
        required: ["jan_code"],
      },
    },
  },
  required: ["lines"],
};

async function readWithGemini(bytes: Uint8Array, mime: string) {
  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) {
    return { error: "GEMINI_API_KEY is not set on the server.", status: 500 };
  }
  const model = Deno.env.get("GEMINI_MODEL") ?? "gemini-2.0-flash";
  const endpoint =
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;
  const payload = {
    contents: [{
      role: "user",
      parts: [
        { text: PROMPT },
        { inline_data: { mime_type: mime, data: encodeBase64(bytes) } },
      ],
    }],
    generationConfig: {
      responseMimeType: "application/json",
      responseSchema: SCHEMA,
      temperature: 0,
    },
  };
  // Send the key as a header (works with both the legacy AIza… keys and the
  // newer AQ.… format) rather than a ?key= query parameter.
  const res = await fetch(endpoint, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-goog-api-key": apiKey,
    },
    body: JSON.stringify(payload),
  });
  if (!res.ok) {
    return { error: `Gemini error ${res.status}: ${await res.text()}`, status: 502 };
  }
  const body = await res.json();
  const text = body?.candidates?.[0]?.content?.parts?.[0]?.text ?? "{}";
  let parsed: { lines?: unknown[] } = {};
  try {
    parsed = JSON.parse(text);
  } catch (_) {
    parsed = {};
  }
  return { lines: Array.isArray(parsed.lines) ? parsed.lines : [] };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ message: "Not found" }, 404);

  try {
    const form = await req.formData();
    const image = form.get("image");
    const provider = (form.get("provider") ?? "gemini").toString();
    if (!(image instanceof File)) {
      return json({ message: "image file is required" }, 400);
    }

    if (provider === "qwen") {
      // Reserved slot — not yet implemented.
      return json({ message: "Qwen provider is not implemented yet." }, 501);
    }
    if (provider !== "gemini") {
      return json({ message: `Unknown provider: ${provider}` }, 400);
    }

    const bytes = new Uint8Array(await image.arrayBuffer());
    const mime = image.type || "image/jpeg";
    const result = await readWithGemini(bytes, mime);
    if ("error" in result) return json({ message: result.error }, result.status);
    return json({ data: { provider: "gemini", lines: result.lines } });
  } catch (e) {
    return json({ message: String(e) }, 500);
  }
});
