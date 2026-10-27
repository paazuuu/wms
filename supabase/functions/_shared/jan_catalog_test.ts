import { assertEquals } from "jsr:@std/assert@1";
import {
  catalogInfo,
  entriesFromItems,
  entriesFromPage,
  makerFromSearch,
  pageLines,
  pagesFromSearch,
  pageWeights,
  segmentRows,
  parseCatalogUrl,
  uniqueEntries,
  validJan,
} from "./jan_catalog.ts";

// A line of characters as the viewer gives them: one <text> each, at x.
function line(y: number, parts: [number, string][]): string {
  let out = "";
  for (const [x0, s] of parts) {
    let x = x0;
    for (const ch of s) {
      const w = ch === "-" ? 1.8 : 4.3;
      out += `<text h="9.5" id="1" w="${w}" x="${x}" y="${y}"><![CDATA[${ch}]]></text>\n`;
      x += w;
    }
  }
  return out;
}
const page = (body: string) => `<?xml version="1.0"?><pdf><page h="841" w="595">${body}</page></pdf>`;

Deno.test("a viewer URL: only a mediapress catalog, its ids read", () => {
  assertEquals(
    parseCatalogUrl(
      "https://dcs.mediapress-net.com/iportal/CatalogViewInterfaceStartUpAction.do?method=startUp&mode=PAGE&volumeID=TST12001&catalogId=1234500000&pageGroupId=&designID=TSTD001&designConfirmFlg=",
    ),
    { host: "dcs.mediapress-net.com", volumeId: "TST12001", catalogId: "1234500000", designId: "TSTD001" },
  );
  assertEquals(parseCatalogUrl("https://example.com/x?volumeID=A&catalogId=1"), null);
  assertEquals(parseCatalogUrl("http://dcs.mediapress-net.com/x?volumeID=A&catalogId=1"), null);
  assertEquals(parseCatalogUrl("https://dcs.mediapress-net.com/x?volumeID=A&catalogId=abc"), null);
  assertEquals(parseCatalogUrl("not a url"), null);
});

Deno.test("the check digit", () => {
  assertEquals(validJan("4909999000014"), true);
  assertEquals(validJan("4909999000015"), false);
  assertEquals(validJan("490999900001"), false);
});

Deno.test("characters into lines and columns: a wide gap is a column", () => {
  const xml = page(
    line(237.3, [[383.4, "TP-F"], [495.4, "49-09999-000014"]]) +
      line(237.9, [[10, "ペン"]]) +
      line(250.1, [[383.4, "TP-M"], [495.4, "49-09999-000021"]]),
  );
  assertEquals(pageLines(xml), [["ペン", "TP-F", "49-09999-000014"], ["TP-M", "49-09999-000021"]]);
});

Deno.test("each JAN with what is printed before it; a bad check digit is not one", () => {
  const xml = page(
    line(100, [[383.4, "TP-F"], [495.4, "49-09999-000014"]]) +
      line(110, [[383.4, "TP-B 4909999000021"]]) +
      line(120, [[383.4, "TP-X"], [495.4, "49-09999-000015"]]) +
      line(130, [[383.4, "¥1,100"]]) +
      // Two to a line, and a JAN column with no 品番 before it.
      line(140, [[10, "-03P"], [60, "49-09999-000038 -34G"], [160, "49-09999-000045"]]) +
      line(150, [[10, "49-09999-000052"], [160, "49-09999-000069"]]),
  );
  const got = entriesFromPage(xml, { id: "1", group: "17", number: "30" });
  assertEquals(got.map((e) => [e.jan, e.code_hint, e.page_number, e.page_group]), [
    ["4909999000014", "TP-F", "30", "17"],
    ["4909999000021", "TP-B", "30", "17"],
    ["4909999000038", "-03P", "30", "17"],
    ["4909999000045", "-34G", "30", "17"],
    ["4909999000052", null, "30", "17"],
    ["4909999000069", null, "30", "17"],
  ]);
  assertEquals(got[0].line_text, "TP-F | 49-09999-000014");
});

Deno.test("one entry per JAN, the first page kept", () => {
  const e = (jan: string, n: string) => ({ jan, code_hint: null, line_text: "", page_number: n, page_group: "" });
  assertEquals(uniqueEntries([e("4909999000014", "3"), e("4909999000014", "9"), e("4909999000021", "9")]).map((x) => x.page_number), [
    "3",
    "9",
  ]);
});

Deno.test("a search result's pages, total and maker; the catalog's name", () => {
  const xml = `<?xml version="1.0"?><response ofs="0" rs="5" total="139" count="1"><catalog>` +
    `<spec><name>メーカー名</name><order>2</order><value>テスト株式会社</value></spec>` +
    `<pagegroup><groupid>17</groupid><page><id>23970020000</id><pid>32</pid><groupid>17</groupid><pos>L</pos><number>30</number>` +
    `<imagelink><id>22011320000</id></imagelink></page></pagegroup></catalog></response>`;
  assertEquals(pagesFromSearch(xml), { total: 139, pages: [{ id: "23970020000", group: "17", number: "30" }] });
  assertEquals(makerFromSearch(xml), "テスト株式会社");
  assertEquals(
    catalogInfo({ result: { article: { listDisplaySpecs: { "カタログ名": "テスト　総合カタログ", "発行年月": "2026年1月1日", "総ページ数": "304ページ" } } } }),
    { name: "テスト 総合カタログ", published: "2026年1月1日", pageCount: 304 },
  );
});

// Synthetic JANs with good check digits.
const J = ["4909999000014", "4909999000021", "4909999000038", "4909999000045", "4909999000052", "4909999000069"];
const weightsBy = (items: { x: number; y: number; w: number; t: string }[]) =>
  Object.fromEntries(
    entriesFromItems(items, { id: "1", group: "5", number: "5" }).map((e) => [e.jan, [e.weight_g, e.weight_basis]]),
  );
const item = (x: number, y: number, t: string, w = t.length * 5) => ({ x, y, w, t });

Deno.test("weights: 「●重量：…」 and a value under a 「…/重量」 heading; a carton's is not the item's", () => {
  const rows = segmentRows([
    item(100, 100, "●重 量：11.5g／パック"),
    item(300, 100, "●質量：1.2kg"),
    item(100, 200, "包装サイズ（幅×厚さ×全長/重量）"),
    item(100, 208, "55×15×191mm/20g"),
    item(100, 220, "物流単位（コ）物流サイズ（mm）重量（g）"),
    item(100, 228, "10 300×200×100 2.5kg"),
    item(300, 208, "40×6×196mm/10g"), // no heading above it
  ]);
  assertEquals(pageWeights(rows).map((w) => [w.g, w.basis]), [[11.5, "pack"], [1200, "product"], [20, "package"]]);
});

Deno.test("a weight under each JAN (one product a block, three blocks across)", () => {
  const got = weightsBy([
    item(120, 100, J[0], 75), item(300, 100, J[1], 75), item(470, 100, J[2], 75),
    item(140, 120, "（幅×厚さ×全長/重量）"), item(320, 120, "（幅×厚さ×全長/重量）"), item(490, 120, "（幅×厚さ×全長/重量）"),
    item(113, 128, "55×15×191mm/20g"), item(293, 128, "40×6×196mm/10g"), item(463, 128, "40×6×196mm/12g"),
    item(120, 300, J[3], 75), item(300, 300, J[4], 75),
    item(140, 320, "（幅×厚さ×全長/重量）"), item(320, 320, "（幅×厚さ×全長/重量）"),
    item(113, 328, "40×6×196mm/8g"), item(293, 328, "40×6×196mm/9g"),
  ]);
  assertEquals(got[J[0]], [20, "product"]);
  assertEquals(got[J[1]], [10, "product"]);
  assertEquals(got[J[2]], [12, "product"]);
  assertEquals(got[J[3]], [8, "product"]);
  assertEquals(got[J[4]], [9, "product"]);
});

Deno.test("a weight above a group of JANs (a product's colours), not the next product's below", () => {
  const got = weightsBy([
    item(290, 170, "●重 量：10.3g／パック", 80),
    item(322, 280, J[0], 60), item(322, 288, J[1], 60), item(322, 296, J[2], 60),
    item(290, 420, "●重 量：23g／パック", 75),
    item(322, 516, J[3], 60), item(322, 524, J[4], 60),
    // Off to the side of every weight: none.
    item(60, 524, J[5], 60),
  ]);
  assertEquals(got[J[0]], [10.3, "pack"]);
  assertEquals(got[J[2]], [10.3, "pack"]);
  assertEquals(got[J[3]], [23, "pack"]);
  assertEquals(got[J[4]], [23, "pack"]);
  assertEquals(got[J[5]], [null, null]);
});

Deno.test("a page that could be read either way gives no weight", () => {
  const got = weightsBy([
    item(100, 100, "●重量：5g", 50),
    item(100, 200, J[0], 60),
    item(100, 300, "●重量：7g", 50),
  ]);
  assertEquals(got[J[0]], [null, null]);
});

Deno.test("one entry per JAN: a later page's weight when the first had none", () => {
  const e = (n: string, g: number | null) => ({
    jan: J[0], code_hint: null, line_text: "", page_number: n, page_group: n,
    weight_g: g, weight_text: g ? `${g}g` : null, weight_basis: g ? "product" as const : null,
  });
  const [u] = uniqueEntries([e("3", null), e("9", 12)]);
  assertEquals([u.page_number, u.weight_g], ["3", 12]);
});
