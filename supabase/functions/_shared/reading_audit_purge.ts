// 読み取り検査 (0224): erasing readings for good — their rows in
// reading_audits and their files in the reading-audits bucket, nothing else.
// Used by the reading-audit function on the service role.

export const READING_AUDIT_BUCKET = "reading-audits";
const BUCKET = READING_AUDIT_BUCKET;
const MAX = 500;

/** The ids asked for: whole positive numbers, each once, at most [MAX]. */
export function readIds(v: unknown): number[] {
  if (!Array.isArray(v)) return [];
  const out: number[] = [];
  for (const x of v) {
    const n = typeof x === "number" ? x : typeof x === "string" && /^\d+$/.test(x) ? Number(x) : NaN;
    if (Number.isSafeInteger(n) && n > 0 && !out.includes(n)) out.push(n);
    if (out.length >= MAX) break;
  }
  return out;
}

// deno-lint-ignore no-explicit-any
type Admin = any;

/** Every file kept under <id>/ (the one attached, and any upload left
 * without its row). */
async function filesOf(admin: Admin, id: number): Promise<string[]> {
  const { data, error } = await admin.storage.from(BUCKET).list(String(id), { limit: 1000 });
  if (error) throw new Error(error.message);
  return ((data ?? []) as { name: string; id: string | null }[]).filter((f) => f.id !== null).map((f) => `${id}/${f.name}`);
}

/** Removes the readings [ids] and those already taken out of the list. */
export async function purgeReadingAudits(admin: Admin, ids: number[]): Promise<{
  removed: number[];
  files: number;
  kept: number[];
}> {
  let q = admin.from("reading_audits").select("id");
  q = ids.length > 0 ? q.or(`id.in.(${ids.join(",")}),removed_at.not.is.null`) : q.not("removed_at", "is", null);
  const { data, error } = await q.limit(MAX * 2);
  if (error) throw new Error(error.message);
  const found = ((data ?? []) as { id: number }[]).map((r) => r.id);
  const gone: number[] = [], kept: number[] = [];
  let files = 0;
  for (const id of found) {
    try {
      const paths = await filesOf(admin, id);
      if (paths.length > 0) {
        const { error: e } = await admin.storage.from(BUCKET).remove(paths);
        if (e) throw new Error(e.message);
        files += paths.length;
      }
      gone.push(id);
    } catch (_) {
      kept.push(id);
    }
  }
  if (gone.length > 0) {
    const { error: e } = await admin.from("reading_audits").delete().in("id", gone);
    if (e) throw new Error(e.message);
  }
  return { removed: gone, files, kept };
}
