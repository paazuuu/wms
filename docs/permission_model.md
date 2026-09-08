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

## 6. Implementation status

**Landed (migration 0012):** `permissions` (21), `roles` (11, per §21),
`role_permissions` (admins hold everything; each operational role an explicit
set), `app_users`, `user_roles`, `user_warehouses`, and the append-only
`audit_log` with its indexes. Guard functions `has_permission(text)`,
`can_access_warehouse(bigint)`, `log_audit(...)` and `my_access()` are in place;
RLS makes the catalogues read-only, restricts a user to their own
user/role/warehouse rows, and gates `audit_log` reads behind `audit.view`.
`log_audit` is deliberately **not** granted to anon/authenticated, so audit rows
can only be written by the service role or other SECURITY DEFINER functions —
the log cannot be forged from a client.

Audit logging is wired into the `warehouses` edge function
(`warehouse.created`, `warehouse.updated`, recording which fields changed).

**Transitional gate — read this before trusting the guards.** The app is still
login-free (anon key), so `auth.uid()` is null and both `has_permission` and
`can_access_warehouse` currently return **true**, matching how the app behaves
today. Nothing is enforced yet; the guards start denying the moment sign-in is
switched on, and an unknown user then holds no permissions and no warehouses.

**Remaining for Step 3:** enable Supabase Auth sign-in, insert `app_users` rows
with roles + `user_warehouses`, replace the `TODO(Step 3)` comments in the
`warehouses` edge function with real `has_permission` / `can_access_warehouse`
checks, and add the same checks to the reconcile/ship RPCs. That last part needs
one product decision first: **who creates accounts and how** (admin-invites vs
self-signup), since it changes the login UX.
