// エラーログ (0227): errors erased for good — rows of app_error_logs and
// nothing else. Used by the app-error-log function on the service role.

const MAX = 5000;

/** What to erase: the ids asked for, and/or everything older than
 * [olderThanDays] days (whole numbers, at least 1). */
export function readErase(body: Record<string, unknown>): { ids: number[]; olderThanDays: number | null } {
  const ids: number[] = [];
  for (const x of Array.isArray(body.ids) ? body.ids : []) {
    const n = typeof x === "number" ? x : typeof x === "string" && /^\d+$/.test(x) ? Number(x) : NaN;
    if (Number.isSafeInteger(n) && n > 0 && !ids.includes(n)) ids.push(n);
    if (ids.length >= MAX) break;
  }
  const d = body.older_than_days;
  const days = typeof d === "number" && Number.isInteger(d) && d >= 1 && d <= 3650 ? d : null;
  return { ids, olderThanDays: days };
}

// deno-lint-ignore no-explicit-any
type Admin = any;

/** Erases the rows; how many went. */
export async function eraseAppErrors(
  admin: Admin,
  what: { ids: number[]; olderThanDays: number | null },
  now = new Date(),
): Promise<number> {
  let n = 0;
  if (what.ids.length > 0) {
    const { data, error } = await admin.from("app_error_logs").delete().in("id", what.ids).select("id");
    if (error) throw new Error(error.message);
    n += (data ?? []).length;
  }
  if (what.olderThanDays !== null) {
    const before = new Date(now.getTime() - what.olderThanDays * 86_400_000).toISOString();
    const { data, error } = await admin.from("app_error_logs").delete().lt("last_at", before).select("id");
    if (error) throw new Error(error.message);
    n += (data ?? []).length;
  }
  return n;
}
