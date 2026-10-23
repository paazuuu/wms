// Seven years after its date, a stock-file import is deleted (0148): its
// record, its lines, and the files kept with it. The stock it moved stays in
// the ledger, so today's stock is not changed by a deletion.
//
// stock_file_expired() (service role only) lists what is due, with every
// file to delete. Files go first: an import whose files could not all be
// deleted is kept for the next run, so no record is lost while its file
// lingers, and no file is left without its record.

export type ExpiredFile = { bucket: string; path: string; document_id?: number };
export type Expired = { id: number; day: string; files: ExpiredFile[] };

/** The few calls this needs of a service-role Supabase client. */
export type PurgeClient = {
  rpc(fn: string, args: Record<string, unknown>): PromiseLike<{ data: unknown; error: { message: string } | null }>;
  storage: {
    from(bucket: string): {
      remove(paths: string[]): PromiseLike<{ data: unknown; error: { message: string } | null }>;
    };
  };
  from(table: string): any;
};

export type PurgeResult = {
  due: number;
  deleted: number[];
  kept: { id: number; reason: string }[];
  files: number;
  documents: number;
  dry_run: boolean;
};

/** Deletes what is due, in one run of at most [limit] imports. */
export async function purgeExpired(admin: PurgeClient, opts: { limit?: number; dryRun?: boolean } = {}): Promise<PurgeResult> {
  const { data, error } = await admin.rpc("stock_file_expired", { p_limit: opts.limit ?? 200 });
  if (error) throw new Error(`stock_file_expired: ${error.message}`);
  const due = (Array.isArray(data) ? data : []) as Expired[];
  const result: PurgeResult = { due: due.length, deleted: [], kept: [], files: 0, documents: 0, dry_run: opts.dryRun === true };
  if (due.length === 0 || opts.dryRun) return result;

  const docs = new Set<number>();
  for (const imp of due) {
    let ok = true;
    const byBucket = new Map<string, string[]>();
    for (const f of imp.files ?? []) {
      if (!f?.bucket || !f?.path) continue;
      byBucket.set(f.bucket, [...(byBucket.get(f.bucket) ?? []), f.path]);
      if (typeof f.document_id === "number") docs.add(f.document_id);
    }
    for (const [bucket, paths] of byBucket) {
      const r = await admin.storage.from(bucket).remove(paths);
      if (r.error) {
        ok = false;
        result.kept.push({ id: imp.id, reason: `${bucket}: ${r.error.message}` });
        break;
      }
      result.files += paths.length;
    }
    if (ok) result.deleted.push(imp.id);
  }
  if (result.deleted.length === 0) return result;

  // The lines go with their import (on delete cascade).
  const del = await admin.from("master_imports").delete().in("id", result.deleted).eq("source", "stock_file");
  if (del.error) throw new Error(`master_imports: ${del.error.message}`);

  // A kept copy goes when no import is left that refers to it.
  if (docs.size > 0) {
    const ids = [...docs];
    const still = await admin.from("master_imports").select("document_id").in("document_id", ids);
    const used = new Set(((still.data ?? []) as { document_id: number }[]).map((r) => r.document_id));
    const free = ids.filter((d) => !used.has(d));
    if (free.length > 0) {
      const d = await admin.from("import_documents").delete().in("id", free).is("delivery_plan_id", null)
        .is("shipment_plan_id", null);
      if (d.error) throw new Error(`import_documents: ${d.error.message}`);
      result.documents = free.length;
    }
  }

  await admin.rpc("log_audit", {
    p_event_type: "inventory.stock_file_purged",
    p_entity_type: "master_import",
    p_entity_id: null,
    p_warehouse_id: null,
    p_details: { imports: result.deleted, files: result.files, documents: result.documents, kept: result.kept },
  });
  return result;
}

/** Whether [given] is the shared secret the database keeps in its vault
 * (purge_expired_secret, made by 0148 and read by nothing but this check).
 * The scheduler sends it; a short or missing one is not even asked about. */
export async function purgeAllowed(admin: PurgeClient, given: string | null): Promise<boolean> {
  if (!given || given.length < 24) return false;
  const { data, error } = await admin.rpc("purge_secret_matches", { p_secret: given });
  return !error && data === true;
}
