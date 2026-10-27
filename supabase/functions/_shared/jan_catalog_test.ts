import { assertEquals } from "jsr:@std/assert@1";
import {
  catalogInfo,
  entriesFromPage,
  makerFromSearch,
  pageLines,
  pagesFromSearch,
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
