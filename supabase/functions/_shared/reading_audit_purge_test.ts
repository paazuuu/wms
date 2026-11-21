import { assertEquals } from "jsr:@std/assert";
import { purgeReadingAudits, readIds } from "./reading_audit_purge.ts";

/** reading_audits and its bucket in memory, as the service role sees them. */
export function fakeAdmin(rows: { id: number; removed: boolean }[], files: Record<string, string[]>, failOn = -1) {
  const erased: number[] = [];
  const removedFiles: string[] = [];
  let filter = "";
  const admin = {
    erased,
    removedFiles,
    from(_t: string) {
      const q = {
        select: () => q,
        or: (f: string) => (filter = f, q),
        not: () => (filter = "removed_only", q),
        limit: () => {
          const asked = filter === "removed_only" ? [] : (/id\.in\.\(([\d,]+)\)/.exec(filter)?.[1] ?? "").split(",").map(Number);
          return Promise.resolve({ data: rows.filter((r) => r.removed || asked.includes(r.id)).map((r) => ({ id: r.id })), error: null });
        },
        delete: () => ({
          in: (_c: string, ids: number[]) => (erased.push(...ids), Promise.resolve({ error: null })),
        }),
      };
      return q;
    },
    storage: {
      from: (_b: string) => ({
        list: (prefix: string) =>
          Promise.resolve({ data: (files[prefix] ?? []).map((name) => ({ name, id: "x" })), error: null }),
        remove: (paths: string[]) => {
          if (paths.some((p) => p.startsWith(`${failOn}/`))) return Promise.resolve({ error: { message: "storage down" } });
          removedFiles.push(...paths);
          return Promise.resolve({ error: null });
        },
      }),
    },
  };
  return admin;
}

Deno.test("the ids asked: whole numbers, each once", () => {
  assertEquals(readIds([3, "4", 3, -1, 1.5, "x", null]), [3, 4]);
  assertEquals(readIds("3"), []);
});

Deno.test("readings erased with their files; those taken out before go too; a file that will not go keeps its row (0224)", async () => {
  const admin = fakeAdmin(
    [{ id: 1, removed: false }, { id: 2, removed: false }, { id: 3, removed: true }, { id: 4, removed: false }, { id: 5, removed: false }],
    { "1": ["a.pdf", "b.pdf"], "3": ["c.xlsx"], "4": ["d.pdf"] },
    4,
  );
  const r = await purgeReadingAudits(admin, [1, 4, 5]);
  assertEquals(r, { removed: [1, 3, 5], files: 3, kept: [4] });
  assertEquals(admin.erased, [1, 3, 5]);
  assertEquals(admin.removedFiles, ["1/a.pdf", "1/b.pdf", "3/c.xlsx"]);
  // Reading 2 was not asked for and not taken out: untouched.
});
