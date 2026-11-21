import { assertEquals } from "jsr:@std/assert";
import { janLookupPrompt, parseJanAnswer } from "./jan_by_code.ts";

const item = { index: 0, code: "UB150.15", maker: "三菱鉛筆", prefixes: ["4902778"] };

Deno.test("a JAN found on the web is kept only when it can be a JAN of the maker (0223)", () => {
  assertEquals(parseJanAnswer('x {"jan":"4902778497807","confidence":0.9} y', item)?.jan, "4902778497807");
  assertEquals(parseJanAnswer('{"jan":"49-02778-497807","confidence":0.9}', item)?.jan, "4902778497807");
  assertEquals(parseJanAnswer('{"jan":"4902778497808","confidence":0.9}', item)?.jan, null, "check digit");
  const other = parseJanAnswer('{"jan":"4902505437847","confidence":0.95,"source_url":"https://e.com"}', item);
  assertEquals([other?.jan, other?.confidence, other?.source_url], [null, 0, null], "another maker's prefix");
  assertEquals(parseJanAnswer('{"jan":"4902505437847","confidence":0.8}', { index: 1, code: "X1", prefixes: [] })?.jan,
    "4902505437847", "no prefix known: the check digit is enough");
  assertEquals(parseJanAnswer("no json", item), null);
  assertEquals(janLookupPrompt(item).includes("品番・型番: UB150.15"), true);
});
