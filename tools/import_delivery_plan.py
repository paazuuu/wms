#!/usr/bin/env python3
"""Import a supplier's advance delivery Excel into Supabase as a delivery plan.

Suppliers format these sheets very differently — the JAN can sit in any column,
the header row may be anywhere, and codes come hyphenated, full-width, or stored
as numbers. This importer therefore:

  * finds the JAN column automatically (the column with the most values that
    normalize to a valid 13/8-digit code),
  * finds the header row and the 数量 / メーカー / 品番 / 単価 / 金額 columns by
    their header text,
  * normalizes every JAN to one canonical form (see normalize_jan), matching the
    app's mobile/lib/features/delivery/domain/jan.dart,
  * aggregates rows that share a JAN.

Usage:
    export SUPABASE_URL=https://<ref>.supabase.co
    export SUPABASE_SERVICE_ROLE_KEY=<service_role key>   # secret! back office only
    python3 tools/import_delivery_plan.py plan.xlsx \
        --delivery-number 20260901-事前 --supplier "事前予定(Excel)"
    # add --dry-run to just print what was detected, without writing.

Requires: openpyxl, requests  (pip install openpyxl requests)
"""
import argparse
import os
import sys

import openpyxl

QTY_KEYS = ["発注数量", "数量", "発注数", "数"]
MAKER_KEYS = ["メーカー", "maker", "ﾒｰｶｰ"]
PNUM_KEYS = ["品番", "商品コード", "品名"]
UNIT_KEYS = ["単価", "定価"]
AMOUNT_KEYS = ["金額", "調達合計金額"]


def normalize_jan(value):
    """Canonical JAN — mirror of jan.dart's normalizeJan."""
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


def detect_and_parse(path):
    wb = openpyxl.load_workbook(path, data_only=True)
    ws = wb.worksheets[0]
    rows = [list(r) for r in ws.iter_rows(values_only=True)]
    ncol = max((len(r) for r in rows), default=0)

    # JAN column = the one with the most valid JAN-looking values.
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

    # Anchor on the 数量 header, then read the other headers from that same row
    # so stray cells elsewhere (e.g. a "繰り越し金額" total) aren't mistaken for
    # the line columns.
    header_row, qty_col = find_cell(QTY_KEYS)

    def find_col(keys):
        if header_row is not None:
            for c, val in enumerate(rows[header_row]):
                if isinstance(val, str) and any(k in val for k in keys):
                    return c
        _, c = find_cell(keys)
        return c

    maker_col = find_col(MAKER_KEYS)
    pnum_col = find_col(PNUM_KEYS)
    unit_col = find_col(UNIT_KEYS)
    amount_col = find_col(AMOUNT_KEYS)

    def cell(r, c):
        return r[c] if (c is not None and c < len(r)) else None

    agg, order = {}, []
    for r in rows:
        jan = normalize_jan(cell(r, jan_col))
        if not is_jan(jan):
            continue
        qty = _to_int(cell(r, qty_col)) or 0
        maker = cell(r, maker_col) or ""
        pnum = cell(r, pnum_col) or ""
        if jan not in agg:
            agg[jan] = {
                "jan_code": jan,
                "product_code": str(pnum),
                "product_name": f"{maker} {pnum}".strip(),
                "planned_quantity": 0,
                "unit_price": _to_int(cell(r, unit_col)),
                "amount": 0,
            }
            order.append(jan)
        agg[jan]["planned_quantity"] += qty
        amt = _to_int(cell(r, amount_col))
        if amt:
            agg[jan]["amount"] += amt

    detected = {
        "jan_col": jan_col, "qty_col": qty_col, "maker_col": maker_col,
        "pnum_col": pnum_col, "unit_col": unit_col, "amount_col": amount_col,
    }
    return [agg[j] for j in order], detected


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("xlsx")
    ap.add_argument("--delivery-number", required=True)
    ap.add_argument("--supplier", default=None)
    ap.add_argument("--delivery-date", default=None, help="YYYY-MM-DD, display only")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    lines, detected = detect_and_parse(args.xlsx)
    print(f"Detected columns (0-based): {detected}")
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
    headers = {
        "apikey": key,
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
        "Prefer": "return=representation",
    }
    plan = {
        "delivery_number": args.delivery_number,
        "supplier_name": args.supplier,
        "delivery_date": args.delivery_date,
        "status": "open",
    }
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
