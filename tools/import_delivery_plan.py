#!/usr/bin/env python3
"""Import a supplier's advance delivery Excel into Supabase as a delivery plan.

The paper delivery notes that arrive later are reconciled against this plan
(JAN is the key), so the app can show what has and hasn't been delivered.

Excel layout expected (1 header row, then data), matching the supplier sheet:

    注文日 | 序号 | メーカー | 品番 | 数量 | 単価 | 金額 | 備考(=JAN)

- JAN code is read from the 備考 column (13 digits).
- product_name = "<メーカー> <品番>", product_code = 品番.
- Rows sharing a JAN are aggregated (quantities summed) into one plan line.
Adjust COL_* below if a different supplier's columns differ.

Usage:
    export SUPABASE_URL=https://<ref>.supabase.co
    export SUPABASE_SERVICE_ROLE_KEY=<service_role key>   # secret! back office only
    python3 tools/import_delivery_plan.py path/to/plan.xlsx \
        --delivery-number 20260829-事前 --supplier "事前予定(Excel)"

Requires: openpyxl, requests  (pip install openpyxl requests)
"""
import argparse
import os
import re
import sys

import openpyxl
import requests

# 0-based column indexes into each row.
COL_MAKER = 2   # メーカー
COL_PNUM = 3    # 品番
COL_QTY = 4     # 数量
COL_UNIT = 5    # 単価
COL_AMOUNT = 6  # 金額
COL_JAN = 7     # 備考 (JAN)

JAN_RE = re.compile(r"^\d{13}$")


def _int(value):
    try:
        return int(round(float(value)))
    except (TypeError, ValueError):
        return None


def parse_xlsx(path):
    wb = openpyxl.load_workbook(path, data_only=True)
    ws = wb.worksheets[0]
    agg = {}
    order = []
    for row in ws.iter_rows(min_row=2, values_only=True):
        if len(row) <= COL_JAN:
            continue
        jan = "" if row[COL_JAN] is None else str(row[COL_JAN]).split(".")[0].strip()
        if not JAN_RE.match(jan):
            continue
        maker = (row[COL_MAKER] or "")
        pnum = (row[COL_PNUM] or "")
        qty = _int(row[COL_QTY]) or 0
        if jan not in agg:
            agg[jan] = {
                "jan_code": jan,
                "product_code": str(pnum),
                "product_name": f"{maker} {pnum}".strip(),
                "planned_quantity": 0,
                "unit_price": _int(row[COL_UNIT]),
                "amount": 0,
            }
            order.append(jan)
        agg[jan]["planned_quantity"] += qty
        amt = _int(row[COL_AMOUNT])
        if amt:
            agg[jan]["amount"] += amt
    return [agg[j] for j in order]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("xlsx")
    ap.add_argument("--delivery-number", required=True)
    ap.add_argument("--supplier", default=None)
    ap.add_argument("--delivery-date", default=None, help="YYYY-MM-DD, display only")
    args = ap.parse_args()

    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    if not url or not key:
        sys.exit("Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY env vars.")

    lines = parse_xlsx(args.xlsx)
    if not lines:
        sys.exit("No JAN rows found — check the column mapping (COL_* constants).")

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

    total = sum(ln["planned_quantity"] for ln in lines)
    print(f"Imported plan #{plan_id} '{args.delivery_number}': "
          f"{len(lines)} JAN lines, {total} units total.")


if __name__ == "__main__":
    main()
