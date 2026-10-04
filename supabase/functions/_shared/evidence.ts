// Every uploaded file kept as evidence (0132).
//
// import-plan and ocr-delivery-note store the file they were sent in the
// private `import-documents` bucket and record it in `import_documents`:
// what it was, who sent it, what it was read as and, once committed, the plan
// it became. The app lists them and downloads them again. A failure to keep a
// file never stops the reading — it is logged and the request goes on.
//
// Writes run on the service role (there are no write policies), but only a
// signed-in user's upload is kept: the user is confirmed on the caller's own
// client first, as everywhere else (see require_permission.ts).

// deno-lint-ignore no-explicit-any
type Client = any;

export const EVIDENCE_PURPOSES = new Set(["plan", "shipment", "training", "quote", "price_book", "library", "ocr"]);

export async function sha256Hex(bytes: Uint8Array): Promise<string> {
  const d = await crypto.subtle.digest("SHA-256", new Uint8Array(bytes));
  return [...new Uint8Array(d)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

/** Where a file is stored: by month and content, so the same file is stored
 * once. */
export function evidencePath(sha: string, fileName: string, now = new Date()): string {
  const ext = (fileName.match(/\.([A-Za-z0-9]{1,8})$/)?.[1] ?? "bin").toLowerCase();
  return `${now.getUTCFullYear()}/${String(now.getUTCMonth() + 1).padStart(2, "0")}/${sha}.${ext}`;
}

/** Stores the file and records it; the id of its record, or null when it
 * could not be kept. The same file sent again for the same purpose before it
 * was committed (a re-read after a column correction) is the same record. */
export async function keepEvidence(
  admin: Client, caller: Client, file: File, bytes: Uint8Array, purpose: string,
  warehouseId: number | null, extra: Record<string, unknown> = {},
): Promise<number | null> {
  try {
    const { data: u } = await caller.auth.getUser();
    const userId = u?.user?.id as string | undefined;
    if (!userId) return null;
    const sha = await sha256Hex(bytes);
    const { data: same } = await admin.from("import_documents").select("id")
      .eq("sha256", sha).eq("purpose", purpose).is("delivery_plan_id", null).is("shipment_plan_id", null)
      .order("id", { ascending: false }).limit(1).maybeSingle();
    if (same) {
      if (Object.keys(extra).length) await noteEvidence(admin, same.id as number, extra);
      return same.id as number;
    }
    const path = evidencePath(sha, file.name);
    const { error: upErr } = await admin.storage.from("import-documents")
      .upload(path, bytes, { contentType: file.type || "application/octet-stream", upsert: true });
    if (upErr) {
      console.error("evidence upload failed", upErr.message);
      return null;
    }
    const { data: company } = await admin.from("companies").select("id").order("id").limit(1).maybeSingle();
    const { data: row, error } = await admin.from("import_documents").insert({
      company_id: company?.id, purpose, file_name: file.name || path, content_type: file.type || null,
      byte_size: bytes.length, sha256: sha, storage_path: path, warehouse_id: warehouseId, uploaded_by: userId,
      ...extra,
    }).select("id").single();
    if (error) {
      console.error("evidence record failed", error.message);
      return null;
    }
    return row.id as number;
  } catch (e) {
    console.error("evidence failed", String(e));
    return null;
  }
}

/** What the file was read as, or the plan it became, on its record. */
export async function noteEvidence(admin: Client, id: number | null, fields: Record<string, unknown>) {
  if (!id) return;
  const { error } = await admin.from("import_documents").update(fields).eq("id", id);
  if (error) console.error("evidence update failed", error.message);
}
