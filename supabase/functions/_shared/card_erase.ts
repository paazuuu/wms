// Cards erased for good (0228), on the service role: a supplier / partner
// card (取引先・価格台帳) or an 国外の仮想在庫 card. What may go and what goes
// with it is asked first, on the caller's token (partner_erase_check,
// overseas_site_erase_check); only the rows those name are touched here.

// deno-lint-ignore no-explicit-any
type Admin = any;

const ids = (v: unknown): number[] =>
  Array.isArray(v) ? v.filter((x): x is number => typeof x === "number" && Number.isSafeInteger(x) && x > 0) : [];

async function must(p: Promise<{ error: { message: string } | null }>, what: string) {
  const { error } = await p;
  if (error) throw new Error(`${what}: ${error.message}`);
}

/** The partner and what belongs only to it. The work records that only
 * name it (imports, documents, wish lists …) keep themselves without it —
 * the database does that (on delete set null), as it erases its readings,
 * names and price terms (on delete cascade). */
export async function erasePartner(admin: Admin, id: number): Promise<void> {
  await must(admin.from("warehouse_products").update({ preferred_supplier_id: null }).eq("preferred_supplier_id", id),
    "warehouse_products");
  await must(admin.from("outbound_file_lines").update({ supplier_id: null }).eq("supplier_id", id), "outbound_file_lines");
  await must(admin.from("supplier_answers").update({ supplier_id: null }).eq("supplier_id", id), "supplier_answers");
  await must(admin.from("purchase_price_entries").delete().eq("supplier_id", id), "purchase_price_entries");
  await must(admin.from("delivery_suppliers").delete().eq("id", id), "delivery_suppliers");
}

/** The site, its stock counts and shipments (their lines first), its notes,
 * and their files. Files first: a file that will not go stops it, so no row
 * is lost while its file stays. */
export async function eraseOverseasSite(admin: Admin, check: Record<string, unknown>): Promise<{ files: number }> {
  const id = Number(check.id);
  if (!Number.isSafeInteger(id) || id <= 0) throw new Error("bad site");
  const imports = ids(check.import_ids), shipments = ids(check.shipment_ids), notes = ids(check.note_ids);
  const noteFiles = Array.isArray(check.note_files) ? check.note_files.filter((p): p is string => typeof p === "string") : [];
  let files = 0;
  const { data: listed, error: le } = await admin.storage.from("overseas-files").list(String(id), { limit: 1000 });
  if (le) throw new Error(`overseas-files: ${le.message}`);
  const own = ((listed ?? []) as { name: string; id: string | null }[]).filter((f) => f.id !== null)
    .map((f) => `${id}/${f.name}`);
  for (const [bucket, paths] of [["overseas-files", own], ["note-files", noteFiles]] as const) {
    if (paths.length === 0) continue;
    const { error } = await admin.storage.from(bucket).remove(paths);
    if (error) throw new Error(`${bucket}: ${error.message}`);
    files += paths.length;
  }
  if (imports.length > 0) {
    await must(admin.from("overseas_stock_lines").delete().in("import_id", imports), "overseas_stock_lines");
    await must(admin.from("overseas_stock_imports").delete().in("id", imports), "overseas_stock_imports");
  }
  if (shipments.length > 0) {
    await must(admin.from("overseas_shipment_lines").delete().in("shipment_id", shipments), "overseas_shipment_lines");
    await must(admin.from("overseas_shipments").delete().in("id", shipments), "overseas_shipments");
  }
  if (notes.length > 0) {
    await must(admin.from("record_note_files").delete().in("note_id", notes), "record_note_files");
    await must(admin.from("record_notes").delete().in("id", notes), "record_notes");
  }
  await must(admin.from("overseas_sites").delete().eq("id", id), "overseas_sites");
  return { files };
}
