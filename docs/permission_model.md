# Permission & Audit Model

_Roles, permissions, warehouse scope, and audit (spec §21, §22, §33, §40, §47)._

## 1. Roles (spec §21)

| Role | Scope |
|---|---|
| System Admin | everything |
| Company Admin | management within a company |
| Warehouse Manager | manage a warehouse |
| Receiving | inbound receiving |
| Inspector | QC / inspection |
| Put-away Operator | put-away |
| Picker | picking |
| Packer | packing |
| Shipper | shipping |
| Inventory Controller | cycle count / adjustments |
| Viewer | read-only |

Roles map to permission sets; a user may hold several. Permissions gate **actions**
(state transitions, writes), not just screen visibility.

## 2. Permissions

Verb-scoped, resource-oriented (mirrors the InventorOS `view_/create_/edit_/
delete_` convention in `findings.md`), e.g. `receiving.confirm`, `inspection.confirm`,
`putaway.confirm`, `pick.confirm`, `pack.complete`, `ship.complete`,
`inventory.adjust`, `count.approve`, `transfer.approve`, `warehouse.manage`,
`user.manage`, `ai.review`.

## 3. Warehouse scope (spec §22)

- `user_warehouses` (user_id, warehouse_id) = `allowed_warehouses`.
- Every read/write validates the target warehouse ∈ the user's allowed set AND the
  active context. Checked in API/RPC. UI hiding is a convenience, not the control.

## 4. Enforcement (spec §47.3–5, §40)

- API/RPC verifies: authenticated user → role permission for the action → tenant
  (company) boundary → warehouse scope → then executes in a transaction.
- Supabase implementation: prefer SECURITY DEFINER RPCs that take the caller's
  identity and re-check role + scope internally, plus RLS policies keyed on
  company/warehouse membership. Never trust client-sent role/warehouse claims.
- Self-approval (e.g. transfer approve) disallowed by default.

## 5. Audit log (spec §33)

`audit_log`: id, company_id, warehouse_id?, actor_user_id, event_type, entity_type,
entity_id, details jsonb, created_at (append-only).

Logged operations (minimum): product change, stock adjustment, receiving confirm,
inspection confirm, ship, warehouse add, warehouse change, role change, permission
change, AI-result approval, inter-warehouse transfer approval.

Every stock movement already carries user + reason + reference; the audit log
captures the higher-level sensitive events with typed JSON details so "who did
what, when, and why" is always answerable.

## 6. Current gap → path

Today the Supabase path is anon/login-free (no roles, no scope). Introducing
Supabase Auth + a `users`/`user_warehouses`/`roles` layer is spec Step 3 and a
prerequisite for real operations. Until then, actions run as a single implicit
operator; the audit log should still record that operator id so history is not
lost when auth arrives.
