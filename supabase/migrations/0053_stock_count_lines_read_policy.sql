-- 0053 — Give `stock_count_lines` a scoped read policy.
--
-- Prerequisite for moving the edge functions' reads onto the caller's client
-- (§37's last piece). It is also the `rls_enabled_no_policy` finding Supabase's
-- advisor has been reporting, now genuinely fixed rather than explained away.
--
-- WHY THE EARLIER REASONING EXPIRED
--
-- 0050 recorded this table as deliberately policy-free: RLS enabled with no
-- policy is the safe direction, and its only reader was `stock-ops/index.ts`
-- on the service-role client, which bypasses RLS. Both halves were true.
--
-- The second half stops being true the moment that read moves to the caller's
-- client, which is exactly what fixing the edge functions' warehouse scope
-- requires. `stock-ops` reads it as an embedded count
-- (`select("*, line_count:stock_count_lines(count)")`), and an embedded read
-- of a table with no policy comes back empty rather than failing loudly — a
-- line count that silently reads 0. So the policy has to land first.
--
-- It is scoped through its parent, the same shape 0052 used for every other
-- child table: a count line belongs to the warehouse its stock count belongs
-- to. `authenticated` only, matching 0049.
--
-- Writes stay service-role-only. No INSERT/UPDATE/DELETE policy is added,
-- because `record_count_line` and friends are `security definer` RPCs that
-- write as the owner and do their own permission checks; giving the
-- `authenticated` role direct write access to count lines would widen the
-- surface for nothing.

create policy "read count lines" on public.stock_count_lines
  for select to authenticated
  using (exists (
    select 1 from public.stock_counts c
     where c.id = stock_count_lines.stock_count_id
       and public.can_access_warehouse(c.warehouse_id)));
