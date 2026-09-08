-- Header auto-read: store the extracted delivery-note header, flag notes whose
-- company could not be read, and let a supplier be matched by its 登録番号.
alter table public.delivery_suppliers
  add column if not exists registration_number text;

alter table public.delivery_plans
  add column if not exists doc_number   text,
  add column if not exists needs_review boolean not null default false;

create index if not exists delivery_suppliers_regno_idx
  on public.delivery_suppliers (registration_number)
  where registration_number is not null;

-- The "未確認" bucket: deliveries whose company could not be identified get a
-- distinct, still-traceable reference series (UNKNOWN-00001, …) and are flagged
-- for manual assignment.
insert into public.delivery_suppliers (code, name)
  values ('UNKNOWN', '未確認（要手動確認）')
  on conflict (code) do nothing;
