// Delivery-note OCR for the WMS mobile client (spec §27–§30, Steps 15–16).
// POST /ocr-delivery-note  (multipart/form-data: image, provider?, plan_id?)
// -> { data: { provider, lines: [{ jan_code, product_name, quantity }],
//              analysis_id, reused } }
//
// Every call is recorded in `ai_analysis` (0026/0027) — AI results never
// reach WMS data directly (docs/ai_architecture.md §1); this endpoint only
// ever hands the client a *candidate* line list, the same as before this
// migration, with the result also persisted PENDING_REVIEW for whoever
// eventually reviews it. Identical images (a retry, a second crop) reuse
// the prior result instead of paying for a second Gemini call.
//
// Providers sit behind the AIProvider interface (spec §27) so a caller
// doesn't know or care which vendor answered — Gemini is the only
// implementation today; `qwen` is a reserved, not-yet-implemented slot.
import { createClient } from "jsr:@supabase/supabase-js@2";
import { encodeBase64 } from "jsr:@std/encoding/base64";
import { encodeHex } from "jsr:@std/encoding/hex";

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

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const TASK_TYPE = "ocr_delivery_note";

// ---------------------------------------------------------------------------
// AIProvider abstraction (spec §27): business code below depends on this
// interface, never on a vendor's request/response shape directly.

interface OcrLineRaw {
  jan_code?: string;
  product_name?: string;
  quantity?: number;
}

interface AIProvider {
  readonly name: string;
  readonly model: string;
  extractDeliveryNote(bytes: Uint8Array, mime: string): Promise<OcrLineRaw[]>;
}

/** Thrown by a provider on failure; carries the HTTP status to respond with. */
class AIProviderError extends Error {
  constructor(message: string, readonly status: number) {
    super(message);
  }
}

const OCR_PROMPT =
  "あなたは日本の物流の納品書を読み取るアシスタントです。この画像の明細表を" +
  "抽出し、各行を {jan_code, product_name, quantity} のJSONで返してください。" +
  "jan_code は商品のバーコード数字（13桁または8桁）で、半角数字のみ・ハイフンや" +
  "空白を含めないこと。住所・電話番号・登録番号(Tで始まる番号)・合計金額などは" +
  "JANとして扱わないこと。数量が読めない行は quantity を省略。表に無い行は返さないこと。";

const OCR_SCHEMA = {
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

class GeminiProvider implements AIProvider {
  readonly name = "gemini";
  readonly model: string;
  private readonly apiKey: string;

  constructor(apiKey: string, model: string) {
    this.apiKey = apiKey;
    this.model = model;
  }

  async extractDeliveryNote(bytes: Uint8Array, mime: string): Promise<OcrLineRaw[]> {
    const endpoint =
      `https://generativelanguage.googleapis.com/v1beta/models/${this.model}:generateContent`;
    const payload = {
      contents: [{
        role: "user",
        parts: [
          { text: OCR_PROMPT },
          { inline_data: { mime_type: mime, data: encodeBase64(bytes) } },
        ],
      }],
      generationConfig: {
        responseMimeType: "application/json",
        responseSchema: OCR_SCHEMA,
        temperature: 0,
      },
    };
    // Send the key as a header (works with both the legacy AIza… keys and the
    // newer AQ.… format) rather than a ?key= query parameter. Retry a few
    // times on transient overload (503 / 429), which Gemini can return during
    // demand spikes, so a busy moment doesn't surface as a user-facing failure.
    let res: Response | null = null;
    for (let attempt = 0; attempt < 4; attempt++) {
      res = await fetch(endpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-goog-api-key": this.apiKey,
        },
        body: JSON.stringify(payload),
      });
      if (res.status !== 503 && res.status !== 429) break;
      if (attempt < 3) {
        await new Promise((r) => setTimeout(r, 700 * (attempt + 1)));
      }
    }
    if (!res || !res.ok) {
      const detail = res ? `${res.status}: ${await res.text()}` : "no response";
      const status = res && (res.status === 503 || res.status === 429) ? 503 : 502;
      throw new AIProviderError(`Gemini error ${detail}`, status);
    }
    const body = await res.json();
    const text = body?.candidates?.[0]?.content?.parts?.[0]?.text ?? "{}";
    let parsed: { lines?: unknown[] } = {};
    try {
      parsed = JSON.parse(text);
    } catch (_) {
      parsed = {};
    }
    return Array.isArray(parsed.lines) ? parsed.lines as OcrLineRaw[] : [];
  }
}

function getProvider(name: string): AIProvider {
  if (name === "gemini") {
    const apiKey = Deno.env.get("GEMINI_API_KEY");
    if (!apiKey) {
      throw new AIProviderError("GEMINI_API_KEY is not set on the server.", 500);
    }
    return new GeminiProvider(apiKey, Deno.env.get("GEMINI_MODEL") ?? "gemini-3.8-flash");
  }
  if (name === "qwen") {
    throw new AIProviderError("Qwen provider is not implemented yet.", 501);
  }
  throw new AIProviderError(`Unknown provider: ${name}`, 400);
}

// ---------------------------------------------------------------------------
// Result store (spec §28): every call — cached hit or fresh provider read —
// is recorded via `ai_analysis`, never written to canonical WMS data here.

async function sha256Hex(bytes: Uint8Array): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return encodeHex(new Uint8Array(digest));
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ message: "Not found" }, 404);

  try {
    const form = await req.formData();
    const image = form.get("image");
    const providerName = (form.get("provider") ?? "gemini").toString();
    if (!(image instanceof File)) {
      return json({ message: "image file is required" }, 400);
    }

    const bytes = new Uint8Array(await image.arrayBuffer());
    const mime = image.type || "image/jpeg";
    const inputHash = await sha256Hex(bytes);

    const { data: reuse, error: reuseError } = await supabase.rpc(
      "find_ai_analysis_reuse",
      { p_task_type: TASK_TYPE, p_input_hash: inputHash },
    );
    if (reuseError) return json({ message: reuseError.message }, 500);

    if (reuse) {
      const lines = (reuse as { output_json?: { lines?: unknown[] } })
        .output_json?.lines ?? [];
      return json({
        data: {
          provider: (reuse as { provider?: string }).provider ?? providerName,
          lines,
          analysis_id: (reuse as { id?: number }).id,
          reused: true,
        },
      });
    }

    const provider = getProvider(providerName);
    const lines = await provider.extractDeliveryNote(bytes, mime);

    const { data: analysisId, error: recordError } = await supabase.rpc(
      "record_ai_analysis",
      {
        p_company_id: null,
        p_warehouse_id: null,
        p_delivery_plan_id: null,
        p_inspection_id: null,
        p_provider: provider.name,
        p_model: provider.model,
        p_task_type: TASK_TYPE,
        p_input_hash: inputHash,
        p_output_json: { lines },
        p_confidence: null,
      },
    );
    if (recordError) return json({ message: recordError.message }, 500);

    return json({
      data: { provider: provider.name, lines, analysis_id: analysisId, reused: false },
    });
  } catch (e) {
    if (e instanceof AIProviderError) return json({ message: e.message }, e.status);
    return json({ message: String(e) }, 500);
  }
});
