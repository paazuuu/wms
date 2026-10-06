// deno test --allow-env supabase/functions/_shared/document_reader_test.ts
import * as XLSX from "npm:xlsx@0.18.5";
import { assert, assertEquals } from "jsr:@std/assert";
import {
  type AliasRow,
  checkJan,
  checkLines,
  checkTotals,
  companyKey,
  headingParts,
  hintText,
  isOwnCompany,
  janCheckOk,
  janLostDigits,
  janShownAsExponent,
  janSurvivingDigits,
  normalizeJan,
  normalizeText,
  ownText,
  pdfHeaderFrom,
  companiesIn,
  companiesInFileName,
  aiErrorKind,
  readingQuality,
  dropTotalsLines,
  pdfTable,
  readRows,
  readSpreadsheet,
  splitAttr,
  splitByRule,
  splitMulti,
  toInt,
  toNum,
  tidyEnglishName,
  forgetAiKey,
  resolveAiKey,
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

Deno.test("a JAN kept whole but shown in exponent form is read right and warned about (0113)", async () => {
  assert(janShownAsExponent(4901480344041, "General"));
  assert(!janShownAsExponent(4901480344041, null));
  assert(janShownAsExponent(4901480344041, "0.00E+00"));
  assert(!janShownAsExponent(4901480344041, "0"));
  assert(!janShownAsExponent("4901480344041", "General"));
  assert(!janShownAsExponent(12345678, "General"));
  const sheet = XLSX.utils.aoa_to_sheet([
    ["JAN", "qty", "maker"],
    [4901480344041, 5, "コクヨ"],
    [4902778198940, 5, "三菱鉛筆"],
  ]);
  sheet["A2"].z = "General";
  sheet["A3"].z = "0";
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, sheet, "s");
  const bytes = new Uint8Array(XLSX.write(wb, { type: "array", bookType: "xlsx" }));
  const { lines } = await readSpreadsheet(bytes, aliases, {}, false);
  assertEquals(lines[0].jan_code, "4901480344041");
  assert(lines[0].flags.includes("jan_display_exponent"));
  assert(!lines[0].flags.includes("jan_exponent"));
  assert(!lines[1].flags.includes("jan_display_exponent"));
});

Deno.test("what survives of a JAN that lost its digits", () => {
  assertEquals(janSurvivingDigits("4.90148E+12"), "490148");
  assertEquals(janSurvivingDigits("4.901480344E+12"), "4901480344");
  assertEquals(janSurvivingDigits("4901480000000"), "490148");
  assertEquals(janSurvivingDigits("4.9E+12"), null);
});

Deno.test("a lost JAN is restored from the 品番 only when the surviving digits agree (0113)", () => {
  const lost = { flags: ["jan_exponent"], raw_jan_code: "4.90148E+12", jan_code: "" };
  const kokuyo = { id: 1, name: "バインダー", jan_code: "4901480344041" };
  const pilot = { id: 2, name: "ペン", jan_code: "4902505591624" };
  const ok = checkJan(lost, null, null, kokuyo);
  assertEquals(ok.flag, "jan_restored");
  assertEquals(ok.restored, kokuyo);
  const bad = checkJan(lost, null, null, pilot);
  assertEquals(bad.flag, "jan_restore_mismatch");
  assertEquals(bad.restored, undefined);
  assertEquals(bad.alternative, "ペン (4902505591624)");
  // Found by name alone, but the digits disagree: dropped, not guessed.
  const byName = checkJan(lost, pilot, "name", null);
  assertEquals(byName.drop, true);
  // Nothing to restore from: stays as it is.
  assertEquals(checkJan(lost, null, null, null), {});
});

Deno.test("a JAN and a 品番 naming two products are flagged (0113)", () => {
  const line = { flags: [], raw_jan_code: "4901480344041", jan_code: "4901480344041" };
  const a = { id: 1, name: "バインダー 灰", jan_code: "4901480344041" };
  const b = { id: 2, name: "バインダー 青", jan_code: "4901480344010" };
  assertEquals(checkJan(line, a, "jan", b).flag, "jan_code_mismatch");
  assertEquals(checkJan(line, a, "jan", b).alternative, "バインダー 青 (4901480344010)");
  assertEquals(checkJan(line, a, "jan", a), {});
  // Matched on the name, not the JAN: nothing to compare.
  assertEquals(checkJan(line, a, "name", b), {});
  // A JAN failing its check digit, with a 品番 we know: say which product.
  const typo = { flags: ["jan_check"], raw_jan_code: "4901480344042", jan_code: "4901480344042" };
  assertEquals(checkJan(typo, null, null, b).alternative, "バインダー 青 (4901480344010)");
});

const known: AliasRow[] = [
  ["JAN", "jan"], ["メーカー", "maker"], ["品名", "product_name"], ["品番", "product_code"], ["数量", "quantity"],
  ["単位", "unit"], ["単価", "unit_price"], ["金額", "amount"], ["備考", "ignore"], ["商品コード", "product_code"],
].map(([k, f]) => ({ header_key: normalizeText(k), field: f as AliasRow["field"], partner: false }));

Deno.test("a heading naming several fields says how its cells split (0114)", () => {
  assertEquals(headingParts("メーカー/品名/品番", known), ["maker", "product_name", "product_code"]);
  assertEquals(headingParts("メーカー・品番", known), ["maker", "product_code"]);
  // A name and a 品番 are name_code, split as before.
  assertEquals(headingParts("品名・品番", known), null);
  assertEquals(headingParts("品名/よく分からない", known), null);
  assertEquals(headingParts("数量", known), null);
});

Deno.test("a combined cell splits in order; the last field keeps what is left (0114)", () => {
  assertEquals(splitMulti("三菱鉛筆／ユニボール エア ０．５ 黒／UBA20105.24", ["maker", "product_name", "product_code"]), {
    maker: "三菱鉛筆", product_name: "ユニボール エア ０．５ 黒", product_code: "UBA20105.24",
  });
  assertEquals(splitMulti("三菱鉛筆／ジェットストリームシングル ０．７／SXN-LS-07 1P#1", ["maker", "product_name", "product_code"]).product_code,
    "SXN-LS-07 1P#1");
  // Spaces: a code first (not read), the maker, then a 品番 with a space in it.
  assertEquals(splitMulti("8D ﾐﾂﾋﾞｼ UMN105EW 33", ["ignore", "maker", "product_code"]), { maker: "ﾐﾂﾋﾞｼ", product_code: "UMN105EW 33" });
  // Shorter than its parts: filled from the end.
  assertEquals(splitMulti("ﾊﾟｲﾛｯﾄ BIL80EFSULB", ["ignore", "maker", "product_code"]), { maker: "ﾊﾟｲﾛｯﾄ", product_code: "BIL80EFSULB" });
  assertEquals(splitMulti("A-1|赤|ペン", ["product_code", "spec", "product_name"], "|"), { product_code: "A-1", spec: "赤", product_name: "ペン" });
  assertEquals(splitAttr("multi:ignore,maker,product_code|space"), {
    field: "multi", attribute: null, parts: ["ignore", "maker", "product_code"], separator: "space",
  });
  assertEquals(splitAttr("multi:maker"), null);
});

Deno.test("text with no digit is no number", () => {
  assertEquals(toInt("税抜金額"), null);
  assertEquals(toNum("単価"), null);
  assertEquals(toInt("3,000"), 3000);
  assertEquals(toNum("62.4"), 62.4);
});

// A text PDF's words, as the PDF places them (x from the left, one line each).
const at = (str: string, x0: number, x1: number) => ({ str, x0, x1, y: 0 });
const crownLike = [
  [at("今回お買上額", 384, 434), at("消費税", 524, 549)],
  [at("328,600", 443, 484), at("32,860", 539, 574)],
  [at("商品ｺｰﾄﾞ", 92, 126), at("JAN", 165, 181), at("メーカー/品名/品番", 334, 401), at("数量", 530, 547),
    at("単位", 560, 577), at("単価", 599, 616), at("金額", 663, 680), at("備考", 747, 764)],
  [at("4902778318232", 137, 205), at("三菱鉛筆／ジェットストリーム０．７赤替／SXRL7.15", 216, 440),
    at("500", 538, 554), at("本", 565, 573), at("63.60", 604, 628), at("31,800", 675, 704)],
  [at("4902778198957", 137, 205), at("三菱鉛筆／ユニボール", 216, 292), at("エア", 298, 311), at("０．５", 317, 342),
    at("黒／UBA20105.24", 348, 423), at("500", 538, 554), at("本", 565, 573), at("106.00", 599, 628), at("53,000", 675, 704)],
  [at("消費税10％対象", 457, 519), at("税抜金額", 534, 568), at("84,800", 594, 628), at("消費税", 639, 664), at("8,480", 675, 704)],
];

Deno.test("a text PDF is laid out into columns by where its words stand (0114)", async () => {
  const table = pdfTable(crownLike, known)!;
  const { columns, lines, totals } = await readRows(table.rows, known, {}, false);
  assertEquals(columns.find((c) => c.header === "メーカー/品名/品番")?.field, "multi");
  assertEquals(lines.length, 2);
  // A name in several pieces stays in its column, the maker included.
  assertEquals(lines[1].maker, "三菱鉛筆");
  assertEquals(lines[1].product_name, "ユニボール エア ０．５ 黒");
  assertEquals(lines[1].product_code, "UBA20105.24");
  assertEquals(lines[1].jan_code, "4902778198957");
  assertEquals([lines[1].planned_quantity, lines[1].unit, lines[1].unit_price, lines[1].amount], [500, "本", 106, 53000]);
  assert(!lines[1].flags.includes("split_single"));
  // The summary row below is not a line; its figure checks the lines.
  assertEquals(totals.lines_sum, 84800);
  assertEquals(totals.ok, true);
});

Deno.test("the lines are checked against the document's totals (0114)", () => {
  const lines = [{ amount: 44000 }, { amount: 570820 }];
  assertEquals(checkTotals(lines, { subtotal: 614820 }).matched, "subtotal");
  assertEquals(checkTotals(lines, { total: 676302, tax: 61482 }).matched, "total_minus_tax");
  const wrong = checkTotals([{ amount: 44000 }, { amount: 507820 }], { subtotal: 614820, total: 676302, tax: 61482 });
  assertEquals(wrong.ok, false);
  assertEquals(wrong.lines_sum, 551820);
  assertEquals(checkTotals(lines, {}).ok, null);
  assertEquals(checkTotals([{ amount: null }], { subtotal: 1 }).ok, null);
});

Deno.test("what a text PDF says of itself", () => {
  const h = pdfHeaderFrom("発 行 日 2026年8月19日\n入金依頼No 009013-260806\n登録番号:T6120001059877\n得意先No.:5001033");
  assertEquals(h.registration_number, "T6120001059877");
  assertEquals(h.doc_date, "2026-08-19");
  assertEquals(h.doc_number, "009013-260806");
  assertEquals(h.customer_code, "5001033");
});

Deno.test("what was learned of a company is told to the AI (0114)", () => {
  const t = hintText({
    columns: [
      { header: "備考", field: "jan" },
      { header: "商品名・品番", field: "multi", parts: ["ignore", "maker", "product_code"], separator: "space" },
    ],
    notes: "1行目の区分記号(9A等)は無視",
  });
  assert(t.includes("見出し『備考』の列には JANコード(jan)"));
  assert(t.includes("見出し『商品名・品番』の欄は空白で区切って 読まない記号・メーカー・品番 の順"));
  assert(t.includes("書式メモ: 1行目の区分記号(9A等)は無視"));
  assertEquals(hintText({}), "");
});

// A sheet printed to PDF with merged cells (縦結合): each item on two lines —
// JAN and maker above, the name below — and its quantity, price and amount
// drawn once, between the two.
const atY = (str: string, x0: number, x1: number, y: number) => ({ str, x0, x1, y });
const mergedLike = [
  [atY("JAN", 60, 80, 700), atY("メーカー", 120, 160, 700), atY("品名", 200, 220, 700), atY("数量", 400, 420, 700),
    atY("単価", 460, 480, 700), atY("金額", 520, 540, 700)],
  [atY("4902778318232", 40, 100, 680), atY("三菱鉛筆", 120, 160, 680)],
  [atY("500", 405, 420, 671), atY("63.60", 460, 485, 671), atY("31,800", 515, 545, 671)],
  [atY("ジェットストリーム 0.7 赤", 190, 300, 662)],
  [atY("4902778198957", 40, 100, 644), atY("三菱鉛筆", 120, 160, 644)],
  [atY("200", 405, 420, 635), atY("106", 462, 480, 635), atY("21,200", 515, 545, 635)],
  [atY("ユニボール エア 0.5 黒", 190, 300, 626)],
  [atY("合計", 200, 220, 600), atY("53,000", 515, 545, 600)],
];

Deno.test("merged cells in a printed PDF: the quantity and the second line join their item", async () => {
  const table = pdfTable(mergedLike, known)!;
  const { lines, totals } = await readRows(table.rows, known, {}, false);
  assertEquals(lines.length, 2);
  assertEquals([lines[0].jan_code, lines[0].maker, lines[0].product_name], ["4902778318232", "三菱鉛筆", "ジェットストリーム 0.7 赤"]);
  assertEquals([lines[0].planned_quantity, lines[0].unit_price, lines[0].amount], [500, 63.6, 31800]);
  assertEquals([lines[1].planned_quantity, lines[1].product_name], [200, "ユニボール エア 0.5 黒"]);
  // The total row stays apart, and checks the lines.
  assertEquals(totals.lines_sum, 53000);
});

Deno.test("no quantity read, but amount ÷ unit price: the quantity, flagged", () => {
  const line = {
    row: 1, jan_code: "4902778318232", raw_jan_code: "4902778318232", maker: "三菱鉛筆", product_name: "x",
    product_code: null, raw_name_code: null, split_by: null, spec: null, planned_quantity: 0, case_quantity: null,
    cases: null, unit_price: 63.6, amount: 31800, tax_rate: null, order_date: null, flags: [] as string[],
    alternatives: {} as Record<string, string | number | null>, attributes: [], list_price: null, discount_rate: null,
    unit: null, supplier_code: null, upstream_code: null, customer_code: null,
  };
  checkLines([line]);
  assertEquals(line.planned_quantity, 500);
  assert(line.flags.includes("qty_from_amount"));
  assert(!line.flags.includes("no_quantity"));
  // A quantity that disagrees with the amount: what the amount says, as the alternative.
  const wrong = { ...line, planned_quantity: 50, flags: [] as string[], alternatives: {} as Record<string, string | number | null> };
  checkLines([wrong]);
  assert(wrong.flags.includes("amount_mismatch"));
  assertEquals(wrong.alternatives.planned_quantity, 500);
});

Deno.test("with our own company known, the other company is the supplier (0131)", () => {
  const own = { names: ["株式会社サンプル文具", "サンプル文具"], registration_number: "T1111111111111" };
  assert(isOwnCompany("(株)サンプル文具 御中", own));
  assert(isOwnCompany("サンプル文具株式会社", own));
  assert(!isOwnCompany("株式会社新東光通商", own));
  assertEquals(companyKey("株式会社 新東光通商"), companyKey("新東光通商(株)"));
  const h = pdfHeaderFrom(
    "納品書\n株式会社サンプル文具 御中\n登録番号 T1111111111111\n株式会社新東光通商\n登録番号:T6120001059877\n2026年10月4日",
    own,
  );
  assertEquals(h.supplier_name, "株式会社新東光通商");
  assertEquals(h.registration_number, "T6120001059877");
  // Our name alone (written without 御中) is still not the supplier.
  const h2 = pdfHeaderFrom("株式会社サンプル文具\nアケボノクラウン株式会社\nT 6120-0010-59877", own);
  assertEquals(h2.supplier_name, "アケボノクラウン株式会社");
  assertEquals(h2.registration_number, "T6120001059877");
  // The AI is told who we are.
  assert(ownText(own).includes("サンプル文具"));
  assertEquals(ownText(null), "");
});

Deno.test("without our name set, the addressee is told from the issuer (0132)", () => {
  // Both at the same height in a text PDF: one line, addressee on the left.
  const h = pdfHeaderFrom(
    "納品書\n株式会社サンプル文具 御中      株式会社新東光通商\n〒530-0001 大阪市北区 TEL 06-0000-0000\n登録番号 T6120001059877",
  );
  assertEquals(h.supplier_name, "株式会社新東光通商");
  assertEquals(h.addressee, "株式会社サンプル文具");
  // The issuer is the one beside the 登録番号, not the first company named.
  const c = companiesIn("アケボノクラウン株式会社\n株式会社ダミー商事\nT 6120-0010-59877\nTEL 06-1111-2222");
  assertEquals(c.candidates[0], "株式会社ダミー商事");
  assertEquals(c.candidates.length, 2);
  // Our name written again without 御中 is still the addressee, not the issuer.
  const h2 = pdfHeaderFrom("株式会社サンプル文具 様\n株式会社サンプル文具\n株式会社新東光通商 TEL 06-0000-0000");
  assertEquals(h2.supplier_name, "株式会社新東光通商");
  // A title is no company.
  assertEquals(pdfHeaderFrom("納品書\n2026年10月4日").supplier_name, null);
});

Deno.test("様 on the line below, and an issuer printed as a logo (0132)", () => {
  // An 入金依頼書 laid out like a real one: our name with 様 under it, the
  // issuer's address, phone and 登録番号 as text, its name only as a logo.
  const text = [
    "入 金 依 頼 書",
    "〒 540-0029",
    "大阪府大阪市中央区本町橋6-19",
    "℡ 06-0000-0000 大阪府東大阪市長田中4-5-6",
    "入金依頼No 009013-260806 電話 06-1111-2222",
    "サンプル商事株式会社",
    "入金希望日 2026年8月21日 FAX 06-1111-3333",
    "様",
    "登録番号:T6120001059877",
  ].join("\n");
  const h = pdfHeaderFrom(text);
  assertEquals(h.addressee, "サンプル商事株式会社");
  assertEquals(h.supplier_name, null);
  assertEquals(h.registration_number, "T6120001059877");
  // The file's name often carries the issuer's.
  assertEquals(
    companiesInFileName("20260819₋361,460₋株式会社ダミー文具₋仕入₋請求書.pdf"),
    ["株式会社ダミー文具"],
  );
  const own = { names: ["サンプル商事株式会社"], registration_number: null };
  assertEquals(companiesInFileName("株式会社ダミー文具_サンプル商事株式会社様_納品書.xlsx", own), ["株式会社ダミー文具"]);
  assertEquals(companiesInFileName("請求書_2026-08.pdf"), []);
});

Deno.test("what kind of AI failure, and how a reading went (0133)", () => {
  assertEquals(aiErrorKind(400, '{"error":{"status":"INVALID_ARGUMENT","message":"API key not valid"}}'), "auth");
  assertEquals(aiErrorKind(403, ""), "auth");
  assertEquals(aiErrorKind(429, ""), "quota");
  assertEquals(aiErrorKind(503, ""), "overload");
  assertEquals(aiErrorKind(400, "bad schema"), "bad_request");
  assertEquals(aiErrorKind(null), "network");
  const q = readingQuality(
    [
      { flags: ["ai_disagree:planned_quantity", "no_maker"] },
      { flags: [] },
      { flags: ["added_by_check"] },
      { flags: ["qty_from_amount"] },
    ],
    "gemini", true, { ok: true },
  );
  assertEquals([q.lines, q.disagree, q.added, q.dropped, q.qty_from_amount, q.totals_ok, q.agreement], [4, 1, 1, 0, 1, true, 0.5]);
  assertEquals(readingQuality([], "xlsx", true, null).agreement, null);
});

Deno.test("a totals row read as a line is taken out by its sum (0134)", async () => {
  // 請求金額 printed under the name column, and the tax with "10" in the
  // quantity column: the lines' own sum doubled before.
  const rows = [
    ["JAN", "品名", "数量", "単価", "金額"],
    ["4902778318232", "ジェットストリーム 赤", "500", "63.60", "31,800"],
    ["4902778198957", "ユニボール エア 黒", "200", "106", "21,200"],
    [null, "お買上金額", null, null, "53,000"],
    [null, "請求金額", null, null, "58,300"],
  ];
  const { lines, totals } = await readRows(rows, known, {}, false);
  assertEquals(lines.length, 2);
  assertEquals(totals.lines_sum, 53000);
  assertEquals(totals.ok, true);
  // On its own: the line equal to the goods with 10% tax goes, a real line stays.
  const line = (amount: number, extra: Partial<Record<string, unknown>> = {}) => ({
    row: 1, jan_code: "", raw_jan_code: null, maker: null, product_name: "x", product_code: null, raw_name_code: null,
    split_by: null, spec: null, planned_quantity: 0, case_quantity: null, cases: null, unit_price: null, amount,
    tax_rate: null, order_date: null, flags: [] as string[], alternatives: {}, attributes: [], list_price: null,
    discount_rate: null, unit: null, supplier_code: null, upstream_code: null, customer_code: null, ...extra,
  }) as Parameters<typeof dropTotalsLines>[0][number];
  const ls = [line(1000, { raw_jan_code: "4902778318232", planned_quantity: 10 }), line(1100), line(70)];
  assertEquals(dropTotalsLines(ls).map((l) => l.amount), [1100]);
  assertEquals(ls.map((l) => l.amount), [1000, 70]);
});

Deno.test("an English name proposal is tidied: no supplier name, no packing count (§43)", () => {
  assertEquals(tidyEnglishName("  Stainless Steel Hex Bolt M8 x 50 mm  "), "Stainless Steel Hex Bolt M8 x 50 mm");
  assertEquals(tidyEnglishName("ABC Hex Bolt M8", "ABC商事株式会社"), "ABC Hex Bolt M8");
  assertEquals(tidyEnglishName("Ueda Hex Bolt M8", "Ueda"), "Hex Bolt M8");
  assertEquals(tidyEnglishName("Hex Bolt M8 x 50 mm 50 pcs"), "Hex Bolt M8 x 50 mm");
  assertEquals(tidyEnglishName(null), "");
});

Deno.test("with no key chosen on the screen, the server's GEMINI_API_KEY is used (0137)", async () => {
  const url = Deno.env.get("SUPABASE_URL");
  Deno.env.delete("SUPABASE_URL");
  Deno.env.set("GEMINI_API_KEY", "server-key-for-test");
  forgetAiKey();
  try {
    const k = await resolveAiKey();
    assertEquals(k.key, "server-key-for-test");
    assertEquals(k.id, null);
    // Trying one registered key never hands out the server key in its place,
    // nor changes the key other calls use.
    const one = await resolveAiKey(7);
    assertEquals([one.id, one.key], [7, null]);
    assertEquals((await resolveAiKey()).key, "server-key-for-test");
  } finally {
    Deno.env.delete("GEMINI_API_KEY");
    if (url) Deno.env.set("SUPABASE_URL", url);
    forgetAiKey();
  }
});
