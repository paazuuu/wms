import { assertEquals } from "jsr:@std/assert@1";
import { fiscalYear, htmlText, htmlTitle, safeReferenceUrl, sha256Hex, snapshotFolder } from "./reference.ts";

Deno.test("a URL that may be saved: http(s) on a public name only", () => {
  assertEquals(safeReferenceUrl("https://example.com/catalog.pdf")?.hostname, "example.com");
  assertEquals(safeReferenceUrl("http://example.co.jp/a")?.protocol, "http:");
  for (const bad of ["ftp://example.com/", "http://localhost/", "http://127.0.0.1/", "http://10.0.0.1/",
    "http://192.168.1.2/", "http://169.254.169.254/latest", "http://[::1]/", "http://intranet/", "file:///etc/passwd",
    "http://printer.local/", "nonsense"]) {
    assertEquals(safeReferenceUrl(bad), null, bad);
  }
  assertEquals(safeReferenceUrl("http://8.8.8.8/")?.hostname, "8.8.8.8");
});

Deno.test("a page's title and its text", () => {
  const html = `<html><head><title> テスト&amp;カタログ </title><style>p{color:red}</style>
    <script>var x = "<p>no</p>";</script></head><body><h1>商品</h1><p>JAN&#58; 4909999000014<br>重量 12g</p>
    <!-- comment --><div>&lt;税込&gt;&nbsp;¥110</div></body></html>`;
  assertEquals(htmlTitle(html), "テスト&カタログ");
  assertEquals(htmlText(html), "テスト&カタログ\n商品\nJAN: 4909999000014\n重量 12g\n<税込> ¥110");
  assertEquals(htmlTitle("<p>no title</p>"), null);
});

Deno.test("a copy's folder in Japan time, and its 年度 (April to March)", async () => {
  assertEquals(snapshotFolder(12, new Date("2026-10-28T06:30:00Z")), "source-12/20261028-153000");
  assertEquals(fiscalYear(new Date("2026-03-31T14:59:59Z")), 2025); // 23:59 on 31 March in Japan
  assertEquals(fiscalYear(new Date("2026-03-31T15:00:00Z")), 2026); // 0:00 on 1 April
  assertEquals((await sha256Hex("abc")).slice(0, 8), "ba7816bf");
});
