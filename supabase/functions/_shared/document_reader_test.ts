// deno test --allow-env supabase/functions/_shared/document_reader_test.ts
import * as XLSX from "npm:xlsx@0.18.5";
import { assert, assertEquals } from "jsr:@std/assert";
import {
  type AliasRow,
  janCheckOk,
  janLostDigits,
  normalizeJan,
  normalizeText,
  readSpreadsheet,
  splitAttr,
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

Deno.test("attribute columns land on our attributes, however the company heads them (0110)", async () => {
  const withAttrs: AliasRow[] = [
    ...aliases,
    { header_key: normalizeText("カラー"), field: "attr", partner: false, attribute: "color" },
    { header_key: normalizeText("Size"), field: "attr", partner: false, attribute: "size" },
    { header_key: normalizeText("品名"), field: "product_name", partner: false },
  ];
  const sheet = XLSX.utils.aoa_to_sheet([
    ["JAN", "品名", "カラー", "Size", "qty"],
    ["4901234567894", "Tシャツ", "BK", "M", 3],
    ["4900000000019", "Tシャツ", "WH", null, 2],
  ]);
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, sheet, "s");
  const bytes = new Uint8Array(XLSX.write(wb, { type: "array", bookType: "xlsx" }));
  const { columns, lines } = await readSpreadsheet(bytes, withAttrs, {}, false);

  assertEquals(columns.map((c) => [c.field, c.attribute ?? null]), [
    ["jan", null], ["product_name", null], ["attr", "color"], ["attr", "size"], ["quantity", null],
  ]);
  assertEquals(lines[0].attributes, [
    { key: "color", name: "カラー", value: "BK" },
    { key: "size", name: "Size", value: "M" },
  ]);
  // No 規格 column: the attributes stand in for it on the slip.
  assertEquals(lines[0].spec, "カラー:BK Size:M");
  assertEquals(lines[1].attributes, [{ key: "color", name: "カラー", value: "WH" }]);

  // An operator can point a column at an attribute.
  const again = await readSpreadsheet(bytes, withAttrs, { 1: "attr:spec" }, false);
  assertEquals([again.columns[1].field, again.columns[1].attribute], ["attr", "spec"]);
});

Deno.test("an override is a field or attr:<attribute>", () => {
  assertEquals(splitAttr("attr:color"), { field: "attr", attribute: "color" });
  assertEquals(splitAttr("jan"), { field: "jan", attribute: null });
  assertEquals(splitAttr("attr"), null);
  assertEquals(splitAttr("attr:"), null);
  assertEquals(splitAttr("nonsense"), null);
});

// Headings and rows as in a real wholesaler's quote (提出用): the
// wholesaler's own 商品コード beside the maker's 品番, 定価 beside the actual
// 見積単価, 単位 and 掛率. (Rows trimmed; no customer or bank data.)
Deno.test("a wholesaler's quote: 品番 over its own 商品コード, 見積単価 over 定価, 単位 and 掛率 read", async () => {
  const quoteAliases: AliasRow[] = [
    ["商品コード", "product_code"], ["品番", "product_code"], ["ブランド名", "maker"], ["商品名", "product_name"],
    ["数量", "quantity"], ["定価", "list_price"], ["単価", "unit_price"], ["掛率", "discount_rate"],
    ["単位", "unit"], ["金額", "amount"], ["JANコード", "jan"], ["備考", "ignore"], ["日付", "order_date"],
  ].map(([k, f]) => ({ header_key: normalizeText(k), field: f as AliasRow["field"], partner: false }));
  const sheet = XLSX.utils.aoa_to_sheet([
    ["行NO", "見積日付", "見積NO", "商品コード", "ブランド名", "品番", "商品名", "数量", "単位", "定価", "見積単価", "掛率", "見積金額", "行備考", "JANコード"],
    [1, 20260831, 131749, 934953, "コクヨ", "ﾙ-PP158M", "C_2穴ﾊﾞｲﾝﾀﾞｰA4 ｸﾞﾚｰ", 60, "ｻﾂ", 910, 465, 0.510989010989011, 27900, "830", "4901480344041"],
    [2, 20260831, 131749, 7245556, "ミツビシ", "UBA20105.15", "ﾕﾆﾎﾞｰﾙ ｴｱ 0.5MM ｱｶ", 200, "P", 200, 104, 0.52, 20800, "830", "4902778198940"],
    [3, 20260831, 131749, 505825, "ゼブラ", "RJLV7-BK", "JLV-0.7芯　黒", 2000, "ﾎﾝ", 100, 49, 0.49, 98000, "830", "4901681171415"],
  ]);
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, sheet, "提出用");
  const bytes = new Uint8Array(XLSX.write(wb, { type: "array", bookType: "xlsx" }));
  const { columns, lines } = await readSpreadsheet(bytes, quoteAliases, {}, false);

  const fieldOf = (h: string) => columns.find((c) => c.header === h)?.field;
  assertEquals(fieldOf("品番"), "product_code");
  assertEquals(fieldOf("商品コード"), "supplier_code");
  assertEquals(fieldOf("定価"), "list_price");
  assertEquals(fieldOf("見積単価"), "unit_price");
  assertEquals(fieldOf("単位"), "unit");
  assertEquals(fieldOf("掛率"), "discount_rate");

  assertEquals(lines.length, 3);
  const [a, b, c] = lines;
  assertEquals(a.product_code, "ﾙ-PP158M");
  assertEquals(a.supplier_code, "934953");
  assertEquals(a.unit_price, 465);
  assertEquals(a.list_price, 910);
  assertEquals(a.unit, "ｻﾂ");
  assertEquals(a.discount_rate, 0.510989010989011);
  assertEquals(a.planned_quantity, 60);
  assertEquals(a.maker, "コクヨ");
  // 60 × 465 = 27,900: the amount agrees once the right price is read.
  assert(!a.flags.includes("amount_mismatch"));
  assertEquals(b.unit_price, 104);
  assertEquals(b.unit, "P");
  assertEquals(c.jan_code, "4901681171415");
  assert(!c.flags.includes("amount_mismatch"));

  // Where 定価 is still known as a price heading, the two price columns are
  // told apart by their headings.
  const older = quoteAliases.map((a) => a.header_key === normalizeText("定価") ? { ...a, field: "unit_price" as const } : a);
  const again = await readSpreadsheet(bytes, older, {}, false);
  assertEquals(again.columns.find((c) => c.header === "定価")?.field, "list_price");
  assertEquals(again.lines[0].unit_price, 465);
});

Deno.test("the wholesaler's codes for its suppliers and for us are read apart from ours (0112)", async () => {
  const quoteAliases: AliasRow[] = [
    ["得意先コード", "customer_code"], ["仕入先コード", "upstream_code"], ["商品コード", "product_code"],
    ["品番", "product_code"], ["ブランド名", "maker"], ["数量", "quantity"], ["JANコード", "jan"], ["店名", "ignore"],
  ].map(([k, f]) => ({ header_key: normalizeText(k), field: f as AliasRow["field"], partner: false }));
  const sheet = XLSX.utils.aoa_to_sheet([
    ["得意先コード", "店名", "商品コード", "仕入先コード", "ブランド名", "品番", "数量", "JANコード"],
    [5001033, "サンプル商店様", 7245556, 724, "", "UBA20105.15", 200, "4902778198940"],
    [5001033, "サンプル商店様", 504048, 50, "ゼブラ", "P-JJ31-BL", 500, "4901681233922"],
  ]);
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, sheet, "s");
  const bytes = new Uint8Array(XLSX.write(wb, { type: "array", bookType: "xlsx" }));
  const { columns, lines } = await readSpreadsheet(bytes, quoteAliases, {}, false);
  const fieldOf = (h: string) => columns.find((c) => c.header === h)?.field;
  assertEquals(fieldOf("仕入先コード"), "upstream_code");
  assertEquals(fieldOf("得意先コード"), "customer_code");
  assertEquals(fieldOf("商品コード"), "supplier_code");
  assertEquals(lines[0].upstream_code, "724");
  assertEquals(lines[0].customer_code, "5001033");
  assertEquals(lines[0].supplier_code, "7245556");
  assertEquals(lines[0].product_code, "UBA20105.15");
  assertEquals(lines[1].maker, "ゼブラ");
});

Deno.test("an order sheet headed ジャパンコード with the JAN as a number reads whole (0112)", async () => {
  const orderAliases: AliasRow[] = [
    ["メーカー", "maker"], ["品番", "product_code"], ["発注数量", "quantity"], ["ジャパンコード", "jan"],
  ].map(([k, f]) => ({ header_key: normalizeText(k), field: f as AliasRow["field"], partner: false }));
  const sheet = XLSX.utils.aoa_to_sheet([
    ["番号", "メーカー", "品番", "ジャパンコード", "発注数量"],
    [830, "kokuyo", "ル-PP158M", 4901480344041, 60],
    [830, "uni", "UBA-201-05.15", 4902778198940, 200],
  ]);
  // Shown as "0" in Excel: the cell holds the number, not the text.
  sheet["D2"].z = "0";
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, sheet, "Sheet1");
  const bytes = new Uint8Array(XLSX.write(wb, { type: "array", bookType: "xlsx" }));
  const { columns, lines } = await readSpreadsheet(bytes, orderAliases, {}, false);
  assertEquals(columns.find((c) => c.header === "ジャパンコード")?.field, "jan");
  assertEquals(lines.map((l) => l.jan_code), ["4901480344041", "4902778198940"]);
  assert(lines.every((l) => !l.flags.includes("jan_check")));

  // Without the heading known, the values still say it is the JAN column.
  const bare = await readSpreadsheet(bytes, orderAliases.filter((a) => a.field !== "jan"), {}, false);
  assertEquals(bare.columns.find((c) => c.header === "ジャパンコード")?.source, "values");
});

Deno.test("a JAN that lost its digits to exponent form is flagged, not guessed (0112)", async () => {
  assert(janLostDigits("4.90148E+12"));
  assert(janLostDigits("4.90148e12"));
  assert(janLostDigits("4901480000000"));
  assert(!janLostDigits("4901480344041"));
  assert(!janLostDigits(4901480344041));
  const sheet = XLSX.utils.aoa_to_sheet([
    ["JAN", "qty", "maker"],
    ["4.90148E+12", 5, "コクヨ"],
    [4901480000000, 5, "コクヨ"],
    ["4901480344041", 5, "コクヨ"],
  ]);
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, sheet, "s");
  const bytes = new Uint8Array(XLSX.write(wb, { type: "array", bookType: "xlsx" }));
  const { lines } = await readSpreadsheet(bytes, aliases, {}, false);
  assertEquals(lines[0].flags.includes("jan_exponent"), true);
  assertEquals(lines[0].jan_code, "");
  assertEquals(lines[1].flags.includes("jan_exponent"), true);
  assertEquals(lines[2].flags.includes("jan_exponent"), false);
  assertEquals(lines[2].jan_code, "4901480344041");
});
