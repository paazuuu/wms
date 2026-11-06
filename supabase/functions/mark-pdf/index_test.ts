import { assertEquals } from "jsr:@std/assert@1";
import { locate, norm } from "./index.ts";

const item = (str: string, x0: number, y: number) => ({ str, x0, x1: x0 + str.length * 5, y, h: 8 });

Deno.test("text compared without width, case or spaces", () => {
  assertEquals(norm("ＪＪ１５－ＢＫ "), "jj15-bk");
});

Deno.test("a row is found by its 品番, not by a quantity alone; each line once", () => {
  const pages = [[
    [item("品番", 40, 700), item("数量", 300, 700)],
    [item("JJ15-BK", 40, 680), item("ゼブラ", 120, 680), item("11000", 300, 680)],
    [item("JJ15-BK", 40, 660), item("ゼブラ", 120, 660), item("10000", 300, 660)],
    [item("ER-KUR", 40, 640), item("20000", 300, 640)],
  ]];
  const m = locate(pages, [
    { i: 3, texts: ["JJ15-BK", "ゼブラ", "11000"] },
    { i: 4, texts: ["JJ15-BK", "ゼブラ", "10000"] },
    { i: 9, texts: ["20000"] },
    { i: 7, texts: ["XX-404"] },
  ]);
  assertEquals(m.get(3)?.page, 0);
  assertEquals(Math.round(m.get(3)!.y), Math.round(680 - 8 * 0.35));
  assertEquals(Math.round(m.get(4)!.y), Math.round(660 - 8 * 0.35), "the second row alike: the next line, by its quantity");
  assertEquals(m.has(9), false, "a bare quantity says nothing");
  assertEquals(m.has(7), false);
});

Deno.test("a PDF with its text: the rows framed where they stand; a scan's rows where the AI says", async () => {
  const { PDFDocument, StandardFonts } = await import("npm:pdf-lib@1.17.1");
  const doc = await PDFDocument.create();
  const page = doc.addPage([595, 842]);
  const font = await doc.embedFont(StandardFonts.Helvetica);
  const rows = [["Item No.", "JAN", "Qty"], ["AB-100", "4909999000014", "10"], ["JJ15-BK", "", "11000"], ["ER-KUR", "", "20000"]];
  rows.forEach((r, n) => r.forEach((t, c) => page.drawText(t, { x: 40 + c * 150, y: 760 - n * 20, size: 10, font })));
  const { markPdf } = await import("./index.ts");
  const asked: number[] = [];
  const r = await markPdf(await doc.save(), [
    { i: 3, texts: ["JJ15-BK", "11000"] },
    { i: 4, texts: ["ER-KUR", "20000"] },
    { i: 9, texts: ["NOT-THERE"] },
  ], async (_b, rest) => {
    asked.push(...rest.map((m) => m.i));
    return new Map([[9, { page: 0, box: [100, 50, 130, 900] }]]);
  });
  assertEquals(r.marked, 3);
  assertEquals(asked, [9], "only what the text could not place goes to the AI");
  const back = await PDFDocument.load(r.out);
  assertEquals(back.getPageCount(), 1);
  await Deno.writeFile(Deno.env.get("MARK_OUT") ?? "/dev/null", r.out);
});
