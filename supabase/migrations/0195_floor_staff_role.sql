-- 0195: 現場スタッフ (floor_staff) — one role for a 通常ユーザー: everything
-- the floor's roles can do (receiving, inspector, putaway_operator, picker,
-- packer, shipper) and 在庫調整 (inventory.adjust). It is not one of the
-- manager roles (0193), so whoever holds it stays a 通常ユーザー; the
-- user-admin function gives it to new 通常ユーザー instead of the six.

insert into public.roles (code, name, description)
select 'floor_staff', 'Floor Staff（現場スタッフ）',
       '通常ユーザー: 入荷・検品・棚入れ・ピッキング・梱包・出荷と在庫調整'
 where not exists (select 1 from public.roles where code = 'floor_staff');

insert into public.role_permissions (role_id, permission_id)
select distinct fs.id, rp.permission_id
  from public.roles fs
  join public.roles r on r.code in ('receiving', 'inspector', 'putaway_operator', 'picker', 'packer', 'shipper')
  join public.role_permissions rp on rp.role_id = r.id
 where fs.code = 'floor_staff'
on conflict do nothing;

insert into public.role_permissions (role_id, permission_id)
select fs.id, p.id
  from public.roles fs, public.permissions p
 where fs.code = 'floor_staff' and p.code = 'inventory.adjust'
on conflict do nothing;
