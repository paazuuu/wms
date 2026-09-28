// Delivery-note OCR for the WMS mobile client (spec §27–§30, Steps 15–16).
// POST /ocr-delivery-note  (multipart/form-data: image, provider?, plan_id?)
// -> { data: { provider, lines: [{ jan_code, product_code, product_name,
//              quantity }], analysis_id, reused } }
//
// Many suppliers print their own item code (品番) and name but no JAN, so a
// line is returned whenever it has any of the three (jan_code may be empty);
// the inspection's match_delivery_note_lines (0101) resolves product_code and
// product_name through supplier_product_names. The reconciliation screen's
// parser still keeps JAN lines only, so its behaviour is unchanged.
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
import { encodeHex } from "jsr:@std/encoding/hex";
import { readDocument } from "../_shared/document_reader.ts";

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
  product_code?: string;
  product_name?: string;
  maker?: string;
  quantity?: number;
  /** What the second reading disagreed on, or a check that failed (0105). */
  flags?: string[];
  alternatives?: Record<string, unknown>;
}

interface OcrResult {
  lines: OcrLineRaw[];
  /** The model's own read-quality self-assessment, 0-1, or null if it didn't
   * return one — never fabricated client-side (spec §31's 信頼度). */
  confidence: number | null;
}

interface AIProvider {
  readonly name: string;
  readonly model: string;
  extractDeliveryNote(bytes: Uint8Array, mime: string): Promise<OcrResult>;
}

/** Thrown by a provider on failure; carries the HTTP status to respond with. */
class AIProviderError extends Error {
  constructor(message: string, readonly status: number) {
    super(message);
  }
}

class GeminiProvider implements AIProvider {
  readonly name = "gemini";
  readonly model: string;
  private readonly apiKey: string;

  constructor(apiKey: string, model: string) {
    this.apiKey = apiKey;
    this.model = model;
  }

  // Since 0105 the note is read twice — an extraction, then an independent
  // check against it — through the shared reader, which also reads the maker,
  // splits a combined 品名・品番 cell, and flags every disagreement.
  async extractDeliveryNote(bytes: Uint8Array, mime: string): Promise<OcrResult> {
    if (!this.apiKey) throw new AIProviderError("GEMINI_API_KEY is not set on the server.", 500);
    try {
      const r = await readDocument(bytes, mime);
      return {
        lines: r.lines.map((l) => ({
          jan_code: l.raw_jan_code ?? "",
          product_code: l.product_code ?? "",
          product_name: l.product_name ?? "",
          maker: l.maker ?? "",
          quantity: l.planned_quantity || undefined,
          flags: l.flags,
          alternatives: l.alternatives,
        })),
        // Not a score anyone measured: none, rather than a made-up one.
        confidence: null,
      };
    } catch (e) {
      const msg = String(e);
      throw new AIProviderError(msg, /\b(503|429)\b/.test(msg) ? 503 : 502);
    }
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
  const digest = await crypto.subtle.digest("SHA-256", bytes as Uint8Array<ArrayBuffer>);
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
    // Optional — links the recorded call back to the plan it was read for
    // (spec §31's 納品書番号 on the AI review screen). Never required: OCR
    // works standalone too (e.g. before a plan exists yet).
    const planIdRaw = form.get("plan_id");
    const planId = planIdRaw != null && `${planIdRaw}`.trim() !== ""
      ? Number(planIdRaw)
      : null;
    const deliveryPlanId = planId != null && Number.isFinite(planId)
      ? planId
      : null;

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
    const { lines, confidence } = await provider.extractDeliveryNote(bytes, mime);

    const { data: analysisId, error: recordError } = await supabase.rpc(
      "record_ai_analysis",
      {
        p_company_id: null,
        p_warehouse_id: null,
        p_delivery_plan_id: deliveryPlanId,
        p_inspection_id: null,
        p_provider: provider.name,
        p_model: provider.model,
        p_task_type: TASK_TYPE,
        p_input_hash: inputHash,
        p_output_json: { lines },
        p_confidence: confidence,
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
