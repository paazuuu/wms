# AI Architecture

_AI as a separate, provider-agnostic layer that never commits WMS data directly
(spec §11, §27–§31, §42)._

## 1. Principles

- AI recognizes, extracts, ranks, and detects anomalies. The WMS records the final
  transaction. AI is not a substitute for the ledger.
- AI results are stored **separately** from WMS canonical data, always with a
  confidence and a human-review step before anything is confirmed.
- No business logic or DB write is bound to a specific vendor API.

## 2. Module shape (spec §27)

```
ai/
  product_identification
  ocr
  image_inspection
  damage_detection
  document_extraction
  inventory_assistant
```

## 3. Provider abstraction (spec §27)

```
AIProvider (interface)
  ├─ AnthropicProvider
  ├─ OpenAIProvider
  ├─ GeminiProvider   ← current OCR (import-plan / ocr-delivery-note) refactors to this
  └─ LocalModelProvider
```

Business code depends on `AIProvider`; the concrete provider is configuration. The
existing Gemini OCR becomes one implementation behind this interface.

## 4. Result store (spec §28)

`ai_analysis`: id, tenant_id, warehouse_id, product_id?, inspection_id?,
attachment_id?, provider, model, task_type, input_uri, input_hash, output_json,
confidence, status (PENDING_REVIEW | CONFIRMED | REJECTED), reviewed_by,
reviewed_at, created_at.

`input_hash` enables idempotent re-use of a prior analysis for the same input. A
wrong AI result never corrupts canonical data — it lives here until a human acts.

## 5. Flows

Product registration from a photo (spec §29):
```
photo → OCR → barcode → AI vision → candidate search → ranked candidates →
human confirm → Product Master
```

Inspection (spec §11, §31): AI returns candidates (product match %, quantity,
damage, label match %, color, model, size, expiry) →
```
AI_RESULT → HUMAN_REVIEW → WMS_CONFIRMED_RESULT
```
UI shows each field with confidence and `[確定] [要確認] [NG]` actions.

OCR (spec §30): targets 納品書 / labels / JAN·UPC·EAN / 送り状 / invoices / box
labels. Store **both** raw text and structured JSON.

## 6. Audit (spec §33, §42)

AI request/complete/review are recorded as events; AI-result approval is an
audited operation. The path
`AI_ANALYSIS_REQUESTED → AI_ANALYSIS_COMPLETED → HUMAN_REVIEW → *_CONFIRMED`
is reconstructable from the log.

## 7. Future assistant (spec §51)

A natural-language assistant ("show low stock in Kobe", "orders due today not yet
picked") calls **safe WMS APIs/tools**, never the DB directly. Tool calls are
scope- and permission-checked like any other action.

## 8. Migration note

Current Gemini OCR is used ad hoc inside edge functions with no result table.
Step 15–16 introduces `ai_analysis` + the provider interface and re-points the
existing OCR through them, preserving today's header/line extraction behavior.
