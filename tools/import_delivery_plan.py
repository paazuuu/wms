#!/usr/bin/env python3
"""Ingest a supplier's advance delivery file (Excel or PDF) into Supabase as a
delivery plan, converting every format to one canonical shape before saving.

Suppliers send these very differently, so the pipeline is:
  file (.xlsx / .pdf)  ->  extract needed fields  ->  normalize  ->  aggregate
  by JAN  ->  write delivery_plans + delivery_plan_lines.

Supported inputs:
  * .xlsx  — JAN column is auto-detected; 数量 / メーカー / 品番 / 単価 / 金額
             columns are found by header text (handles differing layouts).
  * .pdf   — text (born-digital) PDFs are parsed directly: on each row the JAN
             token is found and the first integer after it is the quantity.
             Scanned/image PDFs (no text layer) are sent automatically to the
             deployed ocr-delivery-note Edge Function, where Gemini extracts the
             rows — no local API key needed.
  * images (.jpg/.png/.webp/.heic) — sent to the same Gemini OCR function.
  * --ocr  — force the Gemini OCR path for any input.

Every JAN is passed through normalize_jan (mirror of the app's jan.dart), so the
database always stores one canonical form regardless of hyphens, full-width
digits, Excel's ".0", or a dropped leading zero.

Usage:
    export SUPABASE_URL=https://<ref>.supabase.co
    export SUPABASE_SERVICE_ROLE_KEY=<service_role key>   # secret! back office only
    python3 tools/import_delivery_plan.py plan.xlsx \
        --delivery-number 20260901-事前 --supplier "事前予定" [--dry-run]

Requires: openpyxl (for .xlsx), pypdf (for .pdf), requests (to write).
"""
import argparse
import os
import re
import sys

# Defaults for the Waraku WMS project; override with env vars.
DEFAULT_SUPABASE_URL = "https://vjunicsfobglmncjucbb.supabase.co"
DEFAULT_ANON = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9."
    "eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZqdW5pY3Nmb2JnbG1uY2p1Y2JiIiwicm9sZSI6"
    "ImFub24iLCJpYXQiOjE3ODgzNjMzNDYsImV4cCI6MjEwMzkzOTM0Nn0."
    "lYwz_yl0zi9FvJ37XSGFUpEziiG36bsd_ra8iO5iZ1M"
)

QTY_KEYS = ["発注数量", "数量", "発注数", "数"]
MAKER_KEYS = ["メーカー", "maker", "ﾒｰｶｰ"]
PNUM_KEYS = ["品番", "項目", "商品コード", "品名"]
UNIT_KEYS = ["単価", "定価"]
AMOUNT_KEYS = ["金額", "調達合計金額"]


def normalize_jan(value):
    """Canonical JAN — mirror of mobile/lib/.../jan.dart normalizeJan."""
    if value is None:
        return ""
    s = "".join(
        chr(ord(c) - 0xFF10 + 0x30) if "０" <= c <= "９"
        else ("." if c == "．" else c)
        for c in str(value)
    )
    if "." in s:
        s = s.split(".", 1)[0]
    digits = "".join(c for c in s if c.isdigit())
    if len(digits) == 12:
        digits = "0" + digits
    return digits


def is_jan(d):
    return len(d) in (8, 13)


def _to_int(v):
    try:
        return int(round(float(v)))
    except (TypeError, ValueError):
        return None


def _aggregate(records):
    """records: list of dicts {jan, qty, product_code, product_name, unit, amount}."""
    agg, order = {}, []
    for r in records:
        jan = r["jan"]
        if jan not in agg:
            agg[jan] = {
                "jan_code": jan,
                "product_code": r.get("product_code") or "",
                "product_name": (r.get("product_name") or "").strip(),
                "planned_quantity": 0,
                "unit_price": r.get("unit"),
                "amount": 0,
            }
            order.append(jan)
        agg[jan]["planned_quantity"] += r.get("qty") or 0
        if r.get("amount"):
            agg[jan]["amount"] += r["amount"]
    return [agg[j] for j in order]


# ---------------------------------------------------------------- xlsx --------
def parse_xlsx(path):
    import openpyxl
    wb = openpyxl.load_workbook(path, data_only=True)
    ws = wb.worksheets[0]
    rows = [list(r) for r in ws.iter_rows(values_only=True)]
    ncol = max((len(r) for r in rows), default=0)

    jan_col, best = None, 0
    for c in range(ncol):
        cnt = sum(1 for r in rows if c < len(r) and is_jan(normalize_jan(r[c])))
        if cnt > best:
            best, jan_col = cnt, c
    if jan_col is None or best == 0:
        raise SystemExit("Could not find a JAN column in the sheet.")

    def find_cell(keys):
        for ri, r in enumerate(rows):
            for c, val in enumerate(r):
                if isinstance(val, str) and any(k in val for k in keys):
                    return ri, c
        return None, None

    header_row, qty_col = find_cell(QTY_KEYS)

    def find_col(keys):
        if header_row is not None:
            for c, val in enumerate(rows[header_row]):
                if isinstance(val, str) and any(k in val for k in keys):
                    return c
        return find_cell(keys)[1]

    maker_col = find_col(MAKER_KEYS)
    pnum_col = find_col(PNUM_KEYS)
    unit_col = find_col(UNIT_KEYS)
    amount_col = find_col(AMOUNT_KEYS)

    def cell(r, c):
        return r[c] if (c is not None and c < len(r)) else None

    records = []
    for r in rows:
        jan = normalize_jan(cell(r, jan_col))
        if not is_jan(jan):
            continue
        maker = cell(r, maker_col) or ""
        pnum = cell(r, pnum_col) or ""
        records.append({
            "jan": jan,
            "qty": _to_int(cell(r, qty_col)) or 0,
            "product_code": str(pnum),
            "product_name": f"{maker} {pnum}".strip(),
            "unit": _to_int(cell(r, unit_col)),
            "amount": _to_int(cell(r, amount_col)),
        })
    detected = {"jan_col": jan_col, "qty_col": qty_col, "maker_col": maker_col,
                "pnum_col": pnum_col, "unit_col": unit_col, "amount_col": amount_col}
    return records, detected


# ----------------------------------------------------------------- pdf --------
_INT_RE = re.compile(r"^\d[\d,]*$")


def ocr_via_function(path):
    """Send a scanned PDF or image to the deployed ocr-delivery-note Edge
    Function (Gemini runs server-side) and return canonical records."""
    import mimetypes
    import requests
    base = (os.environ.get("SUPABASE_URL") or DEFAULT_SUPABASE_URL).rstrip("/")
    anon = os.environ.get("SUPABASE_ANON_KEY") or DEFAULT_ANON
    mime = mimetypes.guess_type(path)[0] or "application/octet-stream"
    with open(path, "rb") as fh:
        resp = requests.post(
            f"{base}/functions/v1/ocr-delivery-note",
            headers={"apikey": anon, "Authorization": f"Bearer {anon}"},
            files={"image": (os.path.basename(path), fh, mime)},
            data={"provider": "gemini"},
            timeout=180,
        )
    if resp.status_code != 200:
        raise SystemExit(f"OCR failed ({resp.status_code}): {resp.text}")
    lines = (resp.json().get("data") or {}).get("lines") or []
    records = []
    for ln in lines:
        jan = normalize_jan(ln.get("jan_code"))
        if not is_jan(jan):
            continue
        records.append({
            "jan": jan,
            "qty": _to_int(ln.get("quantity")) or 0,
            "product_code": "",
            "product_name": ln.get("product_name") or "",
            "unit": None,
            "amount": None,
        })
    if not records:
        raise SystemExit("OCR returned no usable JAN rows.")
    return records, {"source": "gemini-ocr", "rows": len(records)}


def parse_pdf(path):
    from pypdf import PdfReader
    reader = PdfReader(path)
    text = "\n".join((pg.extract_text() or "") for pg in reader.pages)
    if not text.strip():
        # Scanned/image PDF: no text layer -> read it with Gemini OCR.
        print("No text layer detected; sending the PDF to Gemini OCR…")
        return ocr_via_function(path)

    records = []
    for line in text.splitlines():
        tokens = line.split()
        jan_idx = next((i for i, t in enumerate(tokens)
                        if is_jan(normalize_jan(t))), None)
        if jan_idx is None:
            continue
        jan = normalize_jan(tokens[jan_idx])
        # Quantity = first plain integer after the JAN (prices usually carry ¥).
        qty = 0
        for t in tokens[jan_idx + 1:]:
            m = _INT_RE.match(t.replace("¥", "").replace("￥", ""))
            if t.startswith("¥") or t.startswith("￥"):
                continue
            if m:
                qty = int(m.group(0).replace(",", ""))
                break
        name = " ".join(tokens[:jan_idx]).strip()
        code = tokens[jan_idx - 1] if jan_idx >= 1 else ""
        records.append({"jan": jan, "qty": qty, "product_code": code,
                        "product_name": name, "unit": None, "amount": None})
    if not records:
        raise SystemExit("No JAN rows found in the PDF text.")
    return records, {"source": "pdf-text", "rows": len(records)}


# ----------------------------------------------------------------- main -------
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("path", help="Excel (.xlsx) or PDF (.pdf) file")
    ap.add_argument("--delivery-number", required=True)
    ap.add_argument("--supplier", default=None)
    ap.add_argument("--delivery-date", default=None, help="YYYY-MM-DD, display only")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--ocr", action="store_true",
                    help="Force Gemini OCR (for scanned files or to override).")
    args = ap.parse_args()

    ext = os.path.splitext(args.path)[1].lower()
    if args.ocr or ext in (".jpg", ".jpeg", ".png", ".webp", ".heic"):
        records, detected = ocr_via_function(args.path)
    elif ext in (".xlsx", ".xlsm"):
        records, detected = parse_xlsx(args.path)
    elif ext == ".pdf":
        records, detected = parse_pdf(args.path)
    else:
        sys.exit(f"Unsupported file type: {ext}")

    lines = _aggregate(records)
    print(f"Source: {detected}")
    print(f"Parsed {len(lines)} unique JAN lines, "
          f"{sum(l['planned_quantity'] for l in lines)} units total.")
    for l in lines[:5]:
        print("  ", l["jan_code"], l["planned_quantity"], l["product_name"])

    if args.dry_run:
        print("(dry-run: nothing written)")
        return

    import requests
    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    if not url or not key:
        sys.exit("Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY env vars.")

    rest = f"{url.rstrip('/')}/rest/v1"
    headers = {"apikey": key, "Authorization": f"Bearer {key}",
               "Content-Type": "application/json", "Prefer": "return=representation"}
    plan = {"delivery_number": args.delivery_number, "supplier_name": args.supplier,
            "delivery_date": args.delivery_date, "status": "open"}
    r = requests.post(f"{rest}/delivery_plans", json=plan, headers=headers, timeout=30)
    r.raise_for_status()
    plan_id = r.json()[0]["id"]
    for ln in lines:
        ln["delivery_plan_id"] = plan_id
    r = requests.post(f"{rest}/delivery_plan_lines", json=lines, headers=headers, timeout=60)
    r.raise_for_status()
    print(f"Imported plan #{plan_id} '{args.delivery_number}'.")


if __name__ == "__main__":
    main()
