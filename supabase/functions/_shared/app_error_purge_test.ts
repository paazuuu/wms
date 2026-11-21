import { assertEquals } from "jsr:@std/assert";
import { eraseAppErrors, readErase } from "./app_error_purge.ts";

Deno.test("what to erase: ids as whole numbers, an age of whole days", () => {
  assertEquals(readErase({ ids: [3, "4", 3, -1, 1.5], older_than_days: 30 }), { ids: [3, 4], olderThanDays: 30 });
  assertEquals(readErase({ older_than_days: 0 }), { ids: [], olderThanDays: null });
  assertEquals(readErase({}), { ids: [], olderThanDays: null });
});

Deno.test("errors erased by id and by age, and only from app_error_logs (0227)", async () => {
  const calls: string[] = [];
  const admin = {
    from: (t: string) => ({
      delete: () => ({
        in: (_c: string, ids: number[]) => ({
          select: () => (calls.push(`${t} in ${ids}`), Promise.resolve({ data: ids.map((id) => ({ id })), error: null })),
        }),
        lt: (_c: string, v: string) => ({
          select: () => (calls.push(`${t} before ${v}`), Promise.resolve({ data: [{ id: 9 }], error: null })),
        }),
      }),
    }),
  };
  const n = await eraseAppErrors(admin, { ids: [1, 2], olderThanDays: 30 }, new Date("2026-11-21T00:00:00Z"));
  assertEquals(n, 3);
  assertEquals(calls, ["app_error_logs in 1,2", "app_error_logs before 2026-10-22T00:00:00.000Z"]);
});
