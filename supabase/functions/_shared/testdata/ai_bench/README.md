# AI model comparison: reading an invoice

A made-up invoice (no real company, JANs 4909999000014–45) to compare the
Gemini models on what `readDocument` asks of them.

- `invoice.html` is the source. `invoice_clean.jpg` is its screenshot, and
  `invoice_blurred.jpg` the same tilted, blurred and shrunk, like a poor
  phone photo.
- `request_*.json` is the `generateContent` body for each picture, built
  with `EXTRACT_PROMPT` and `EXTRACT_SCHEMA` from `document_reader.ts`.

What a correct reading has: 4 lines, 120 / 60 / 200 / 15, units 本 本 本 冊,
prices 88 / 88 / 33 / 110, subtotal 24,090, tax 2,409, total 26,697, date
2026-10-20, supplier サンプル文具株式会社, T1234567890123.
