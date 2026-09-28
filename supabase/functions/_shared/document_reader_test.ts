// deno test --allow-env supabase/functions/_shared/document_reader_test.ts
import * as XLSX from "npm:xlsx@0.18.5";
import { assert, assertEquals } from "jsr:@std/assert";
import {
  type AliasRow,
  janCheckOk,
  normalizeJan,
  normalizeText,
  readSpreadsheet,
  splitByRule,
} from "./document_reader.ts";

Deno.test("a JAN written any company's way is one JAN", () => {
  for (const v of ["4901-2345-67894", "4901.2345.67894", "4901 2345 67894", "4901_2345_67894",
                   "４９０１２３４５６７８９４", "4901234567894.0", 4901234567894]) {
    assertEquals(normalizeJan(v), "4901234567894");
  }
  assertEquals(normalizeJan("14901234567894").length, 13);
  assert(janCheckOk("4901234567894"));
  assert(!janCheckOk("4901234567890"));
});

Deno.test("text folds widths, kana and punctuation like the database", () => {
  assertEquals(normalizeText("ﾃｽﾄ文具"), normalizeText("てすと文具"));
  assertEquals(normalizeText("BP.05K"), normalizeText("bp_05-k"));
  assertEquals(normalizeText("1.5L"), "1.5l");
  assertEquals(normalizeText("ｼｮｳﾋﾝﾒｲ"), "しょうひんめい");
});

Deno.test("name and 品番 in one cell split by rule", () => {
  assertEquals(splitByRule("ボールペン 黒 0.5 (BP-05K)"), { name: "ボールペン 黒 0.5", code: "BP-05K" });
  assertEquals(splitByRule("BP-05K ボールペン黒"), { name: "ボールペン黒", code: "BP-05K" });
  assertEquals(splitByRule("ボールペン黒 / BP-05K"), { name: "ボールペン黒", code: "BP-05K" });
  assertEquals(splitByRule("ボールペン黒"), null);
});

const aliases: AliasRow[] = [
  ["jan", "jan"], ["maker", "maker"], ["品名品番", "name_code"], ["qty", "quantity"],
  ["入数", "case_quantity"], ["ケース数", "cases"], ["unitprice", "unit_price"],
  ["しょうひんめい", "product_name"],
].map(([k, f]) => ({ header_key: normalizeText(k), field: f as AliasRow["field"], partner: false }));

Deno.test("a sheet headed in English and kana, with a combined column, reads", async () => {
  const sheet = XLSX.utils.aoa_to_sheet([
    ["納品明細", null, null, null, null, null],
    ["JAN Code", "Maker", "品名・品番", "入数", "ケース数", "Unit Price"],
    ["4901-2345-67894", "Test Bungu", "ボールペン黒 (BP-05K)", 12, 5, 100],
    [4901234567900, "ﾃｽﾄ文具", "A-100 消しゴム", 10, 2, 50],
    ["合計", null, null, null, null, null],
  ]);
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, sheet, "s");
  const bytes = new Uint8Array(XLSX.write(wb, { type: "array", bookType: "xlsx" }));
  const { columns, lines } = await readSpreadsheet(bytes, aliases, {}, false);

  assertEquals(columns.map((c) => c.field), ["jan", "maker", "name_code", "case_quantity", "cases", "unit_price"]);
  assertEquals(lines.length, 2);
  assertEquals(lines[0].jan_code, "4901234567894");
  assertEquals(lines[0].raw_jan_code, "4901-2345-67894");
  assertEquals(lines[0].product_name, "ボールペン黒");
  assertEquals(lines[0].product_code, "BP-05K");
  assertEquals(lines[0].planned_quantity, 60);
  assert(lines[0].flags.includes("qty_from_cases"));
  assertEquals(lines[1].product_code, "A-100");
  assertEquals(lines[1].maker, "ﾃｽﾄ文具");
});
