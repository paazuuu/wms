import { assertEquals, assertRejects } from "jsr:@std/assert";
import { eraseOverseasSite, erasePartner } from "./card_erase.ts";

/** The service role in memory: what it was asked, in order. */
export function fakeAdmin(files: Record<string, string[]> = {}, failBucket?: string) {
  const calls: string[] = [];
  const done = { error: null };
  const admin = {
    calls,
    from: (t: string) => ({
      update: (v: Record<string, unknown>) => ({
        eq: (c: string, x: unknown) => (calls.push(`${t} set ${Object.keys(v)} where ${c}=${x}`), Promise.resolve(done)),
      }),
      delete: () => ({
        eq: (c: string, x: unknown) => (calls.push(`${t} erase ${c}=${x}`), Promise.resolve(done)),
        in: (c: string, x: unknown[]) => (calls.push(`${t} erase ${c} in ${x}`), Promise.resolve(done)),
      }),
    }),
    storage: {
      from: (b: string) => ({
        list: (prefix: string) =>
          Promise.resolve({ data: (files[`${b}:${prefix}`] ?? []).map((name) => ({ name, id: "x" })), error: null }),
        remove: (paths: string[]) => {
          if (b === failBucket) return Promise.resolve({ error: { message: "down" } });
          calls.push(`${b} remove ${paths}`);
          return Promise.resolve(done);
        },
      }),
    },
  };
  return admin;
}

Deno.test("a partner: its links let go, its prices with it, then the card (0228)", async () => {
  const admin = fakeAdmin();
  await erasePartner(admin, 7);
  assertEquals(admin.calls, [
    "warehouse_products set preferred_supplier_id where preferred_supplier_id=7",
    "outbound_file_lines set supplier_id where supplier_id=7",
    "supplier_answers set supplier_id where supplier_id=7",
    "purchase_price_entries erase supplier_id=7",
    "delivery_suppliers erase id=7",
  ]);
});

Deno.test("an overseas card: files first, lines before what holds them, the card last", async () => {
  const admin = fakeAdmin({ "overseas-files:3": ["a.xlsx"] });
  const r = await eraseOverseasSite(admin, {
    id: 3, import_ids: [10, 11], shipment_ids: [20], note_ids: [30], note_files: ["overseas_site/3/n.pdf"],
  });
  assertEquals(r.files, 2);
  assertEquals(admin.calls, [
    "overseas-files remove 3/a.xlsx",
    "note-files remove overseas_site/3/n.pdf",
    "overseas_stock_lines erase import_id in 10,11",
    "overseas_stock_imports erase id in 10,11",
    "overseas_shipment_lines erase shipment_id in 20",
    "overseas_shipments erase id in 20",
    "record_note_files erase note_id in 30",
    "record_notes erase id in 30",
    "overseas_sites erase id=3",
  ]);
});

Deno.test("a file that will not go stops it before any row goes", async () => {
  const admin = fakeAdmin({ "overseas-files:3": ["a.xlsx"] }, "overseas-files");
  await assertRejects(() => eraseOverseasSite(admin, { id: 3, import_ids: [10] }));
  assertEquals(admin.calls, []);
});
