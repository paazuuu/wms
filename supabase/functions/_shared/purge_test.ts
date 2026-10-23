import { assertEquals } from "jsr:@std/assert@1";
import { purgeAllowed, type PurgeClient, purgeExpired } from "./purge.ts";

type Call = [string, ...unknown[]];

function fake(due: unknown[], opts: { failBucket?: string; stillUsed?: number[] } = {}) {
  const calls: Call[] = [];
  const query = (table: string) => {
    const q: any = {
      _op: "select",
      delete() { q._op = "delete"; return q; },
      select() { q._op = "select"; return q; },
      in(col: string, vals: unknown[]) { calls.push([`${table}.${q._op}.in`, col, vals]); return q; },
      eq(col: string, v: unknown) { calls.push([`${table}.${q._op}.eq`, col, v]); return q; },
      is(col: string, v: unknown) { calls.push([`${table}.${q._op}.is`, col, v]); return q; },
      then(res: (v: unknown) => unknown) {
        const data = table === "master_imports" && q._op === "select"
          ? (opts.stillUsed ?? []).map((d) => ({ document_id: d }))
          : null;
        return Promise.resolve({ data, error: null }).then(res);
      },
    };
    return q;
  };
  const client: PurgeClient = {
    rpc(fn, args) {
      calls.push(["rpc", fn, args]);
      return Promise.resolve({ data: fn === "stock_file_expired" ? due : null, error: null });
    },
    storage: {
      from(bucket) {
        return {
          remove(paths) {
            calls.push(["remove", bucket, paths]);
            return Promise.resolve({ data: null, error: bucket === opts.failBucket ? { message: "boom" } : null });
          },
        };
      },
    },
    from: query,
  };
  return { client, calls };
}

const due = [
  { id: 3, day: "2018-01-01", files: [{ bucket: "master-import-files", path: "imports/3/original-a.pdf" },
    { bucket: "import-documents", path: "2018/01/x.pdf", document_id: 40 }] },
  { id: 4, day: "2018-02-01", files: [] },
];

Deno.test("files go first, then the records and the copies nothing else needs", async () => {
  const { client, calls } = fake(due, { stillUsed: [] });
  const r = await purgeExpired(client);
  assertEquals(r.deleted, [3, 4]);
  assertEquals(r.files, 2);
  assertEquals(r.documents, 1);
  assertEquals(calls.filter((c) => c[0] === "remove").map((c) => c[1]), ["master-import-files", "import-documents"]);
  assertEquals(calls.find((c) => c[0] === "master_imports.delete.in"), ["master_imports.delete.in", "id", [3, 4]]);
  assertEquals(calls.find((c) => c[0] === "master_imports.delete.eq"), ["master_imports.delete.eq", "source", "stock_file"]);
  assertEquals(calls.find((c) => c[0] === "import_documents.delete.in"), ["import_documents.delete.in", "id", [40]]);
  assertEquals(calls.some((c) => c[0] === "rpc" && c[1] === "log_audit"), true);
});

Deno.test("an import whose file could not be deleted is kept for the next run", async () => {
  const { client, calls } = fake(due, { failBucket: "import-documents" });
  const r = await purgeExpired(client);
  assertEquals(r.deleted, [4]);
  assertEquals(r.kept.map((k) => k.id), [3]);
  assertEquals(calls.find((c) => c[0] === "master_imports.delete.in"), ["master_imports.delete.in", "id", [4]]);
});

Deno.test("a copy another import still refers to stays", async () => {
  const { client, calls } = fake(due, { stillUsed: [40] });
  const r = await purgeExpired(client);
  assertEquals(r.documents, 0);
  assertEquals(calls.some((c) => c[0] === "import_documents.delete.in"), false);
});

Deno.test("a dry run deletes nothing; nothing due does nothing", async () => {
  const dry = fake(due);
  assertEquals((await purgeExpired(dry.client, { dryRun: true })).due, 2);
  assertEquals(dry.calls.filter((c) => c[0] !== "rpc").length, 0);
  const none = fake([]);
  assertEquals((await purgeExpired(none.client)).deleted, []);
  assertEquals(none.calls.length, 1);
});

Deno.test("only the vault's secret opens it; a short one is not even asked about", async () => {
  const asked: unknown[] = [];
  const client = {
    rpc(fn: string, args: Record<string, unknown>) {
      asked.push([fn, args]);
      return Promise.resolve({ data: args.p_secret === "s".repeat(48), error: null });
    },
  } as unknown as PurgeClient;
  assertEquals(await purgeAllowed(client, "s".repeat(48)), true);
  assertEquals(await purgeAllowed(client, "t".repeat(48)), false);
  assertEquals(asked.length, 2);
  assertEquals(await purgeAllowed(client, "short"), false);
  assertEquals(await purgeAllowed(client, null), false);
  assertEquals(asked.length, 2);
});
