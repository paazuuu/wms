-- 0171: 会計 → 支払い. Each invoice taken into stock (ファイルから在庫登録) is
-- a payment to make: to whom (the supplier and the 振込先 the invoice
-- prints), how much, the invoice itself, whether it is paid — the same
-- 支払い済 as on the import (0148), so the two stay one — and the proof of
-- the transfer (振込完了の画面など) kept beside it.
--
-- * import_documents.payee: the 振込先 as read from the invoice (import-plan
--   reads it into the header instead of taking it for goods lines).
-- * delivery_suppliers.bank_account: the supplier's 振込先, kept from the
--   first invoice that prints one, and set by hand on the payments screen;
--   used when an invoice prints none.
-- * payment_proofs: files in the private `payment-proofs` bucket, per
--   import. Taken off by marking (removed_at); the file stays.
-- * payments_list(from, to, unpaid_only): the imports with all of that.
-- Who: those who may see the books (0168) see it; those who note imports
-- (inventory.adjust, as for 支払い済) record payments.

alter table public.import_documents add column if not exists payee jsonb;

alter table public.delivery_suppliers add column if not exists bank_account jsonb;
alter table public.delivery_suppliers add column if not exists bank_account_at timestamptz;
alter table public.delivery_suppliers add column if not exists bank_account_by_name text;

create or replace function public.can_record_payments()
returns boolean
language sql stable security definer set search_path = '' as $$
  select public.has_permission('inventory.adjust');
$$;
grant execute on function public.can_record_payments() to authenticated;

-- A supplier's 振込先 comes from the first invoice that prints one; one set
-- by hand is not overwritten by a reading.
create or replace function public.import_documents_payee_to_supplier()
returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.supplier_id is not null and nullif(new.payee->>'bank', '') is not null then
    update public.delivery_suppliers
       set bank_account = new.payee, bank_account_at = now(), bank_account_by_name = null
     where id = new.supplier_id and bank_account is null;
  end if;
  return new;
end;
$$;
revoke all on function public.import_documents_payee_to_supplier() from public, anon, authenticated;
create or replace trigger import_documents_payee_to_supplier
  after insert or update of payee, supplier_id on public.import_documents
  for each row execute function public.import_documents_payee_to_supplier();

insert into storage.buckets (id, name, public, file_size_limit)
values ('payment-proofs', 'payment-proofs', false, 20971520)
on conflict (id) do nothing;

do $$
begin
  if not exists (select 1 from pg_policies where schemaname = 'storage' and policyname = 'payment-proofs: recorders upload') then
    create policy "payment-proofs: recorders upload" on storage.objects
      for insert to authenticated
      with check (bucket_id = 'payment-proofs' and public.can_record_payments());
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'storage' and policyname = 'payment-proofs: book viewers read') then
    create policy "payment-proofs: book viewers read" on storage.objects
      for select to authenticated
      using (bucket_id = 'payment-proofs' and public.can_view_purchase_books());
  end if;
end $$;

create table if not exists public.payment_proofs (
  id bigint generated always as identity primary key,
  import_id bigint not null references public.master_imports (id),
  storage_path text not null unique,
  file_name text not null,
  content_type text,
  byte_size bigint,
  note text,
  created_at timestamptz not null default now(),
  created_by uuid,
  created_by_name text,
  -- Taken off the list: kept, marked.
  removed_at timestamptz,
  removed_by_name text
);
create index if not exists payment_proofs_import on public.payment_proofs (import_id);
alter table public.payment_proofs enable row level security;
do $$
begin
  if not exists (select 1 from pg_policies where tablename = 'payment_proofs' and policyname = 'payment_proofs_read') then
    create policy payment_proofs_read on public.payment_proofs
      for select to authenticated using (public.can_view_purchase_books());
  end if;
end $$;
grant select on public.payment_proofs to authenticated;

create or replace function public.add_payment_proof(
  p_import_id bigint, p_path text, p_name text, p_type text default null, p_size bigint default null, p_note text default null)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_row public.payment_proofs;
begin
  if not public.can_record_payments() then
    raise exception 'not permitted: inventory.adjust required';
  end if;
  if not exists (select 1 from public.master_imports where id = p_import_id and source = 'stock_file') then
    raise exception 'import % not found', p_import_id;
  end if;
  if coalesce(p_path, '') !~ ('^' || p_import_id || '/') then
    raise exception 'proof path must be under the import';
  end if;
  insert into public.payment_proofs (import_id, storage_path, file_name, content_type, byte_size, note, created_by, created_by_name)
  values (p_import_id, p_path, coalesce(nullif(btrim(p_name), ''), p_path), p_type, p_size,
          nullif(btrim(coalesce(p_note, '')), ''), auth.uid(), public.user_display_name(auth.uid()))
  returning * into v_row;
  perform public.log_audit('payment.proof_added', 'master_import', p_import_id::text, null,
                           jsonb_build_object('proof_id', v_row.id, 'file_name', v_row.file_name));
  return to_jsonb(v_row);
end;
$$;
revoke all on function public.add_payment_proof(bigint, text, text, text, bigint, text) from public, anon;
grant execute on function public.add_payment_proof(bigint, text, text, text, bigint, text) to authenticated;

create or replace function public.remove_payment_proof(p_id bigint)
returns boolean
language plpgsql security definer set search_path = '' as $$
begin
  if not public.can_record_payments() then
    raise exception 'not permitted: inventory.adjust required';
  end if;
  update public.payment_proofs set removed_at = now(), removed_by_name = public.user_display_name(auth.uid())
   where id = p_id and removed_at is null;
  return found;
end;
$$;
revoke all on function public.remove_payment_proof(bigint) from public, anon;
grant execute on function public.remove_payment_proof(bigint) to authenticated;

-- [p_account]: {bank, branch, account_type, account_number, holder}; null or
-- {} clears it.
create or replace function public.set_supplier_bank_account(p_supplier_id bigint, p_account jsonb)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v jsonb := case when p_account is null or p_account = '{}'::jsonb then null else jsonb_strip_nulls(jsonb_build_object(
    'bank', nullif(btrim(coalesce(p_account->>'bank', '')), ''),
    'branch', nullif(btrim(coalesce(p_account->>'branch', '')), ''),
    'account_type', nullif(btrim(coalesce(p_account->>'account_type', '')), ''),
    'account_number', nullif(regexp_replace(coalesce(p_account->>'account_number', ''), '[^0-9]', '', 'g'), ''),
    'holder', nullif(btrim(coalesce(p_account->>'holder', '')), ''))) end;
begin
  if not public.can_record_payments() then
    raise exception 'not permitted: inventory.adjust required';
  end if;
  update public.delivery_suppliers
     set bank_account = case when v = '{}'::jsonb then null else v end,
         bank_account_at = now(), bank_account_by_name = public.user_display_name(auth.uid())
   where id = p_supplier_id;
  if not found then
    raise exception 'supplier % not found', p_supplier_id;
  end if;
  perform public.log_audit('payment.bank_account_set', 'delivery_supplier', p_supplier_id::text, null, coalesce(v, '{}'::jsonb));
  return v;
end;
$$;
revoke all on function public.set_supplier_bank_account(bigint, jsonb) from public, anon;
grant execute on function public.set_supplier_bank_account(bigint, jsonb) to authenticated;

-- The payments: as tax_purchases (0168), with the supplier, its 振込先 (the
-- invoice's, else the supplier's), who marked it paid, and the proofs.
-- [p_unpaid_only]: every unpaid one, whatever its date.
create or replace function public.payments_list(p_from date, p_to date, p_unpaid_only boolean default false)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.can_view_purchase_books() then
    raise exception 'not permitted: report.view required';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', m.id, 'day', d.day, 'document_date', m.document_date,
             'document_date_source', m.document_date_source,
             'created_at', m.created_at, 'status', m.status,
             'original_name', m.original_name, 'original_path', m.original_path, 'original_type', m.original_type,
             'paid', m.paid, 'paid_at', m.paid_at, 'paid_by_name', public.user_display_name(m.paid_by), 'note', m.note,
             'warehouse_name', w.name, 'read_lines', coalesce(m.read_lines, '[]'::jsonb),
             'supplier_id', s.id, 'supplier_display_name', s.name,
             'payee', coalesce(doc.payee, s.bank_account),
             'payee_source', case when doc.payee is not null then 'invoice'
                                  when s.bank_account is not null then 'supplier' end,
             'supplier_bank_account', s.bank_account,
             'proofs', coalesce((
               select jsonb_agg(jsonb_build_object(
                        'id', p.id, 'storage_path', p.storage_path, 'file_name', p.file_name,
                        'content_type', p.content_type, 'byte_size', p.byte_size, 'note', p.note,
                        'created_at', p.created_at, 'created_by_name', p.created_by_name)
                      order by p.created_at)
                 from public.payment_proofs p
                where p.import_id = m.id and p.removed_at is null), '[]'::jsonb),
             'document', case when doc.id is null then null else jsonb_build_object(
               'id', doc.id, 'supplier_name', coalesce(s.name, doc.supplier_name),
               'registration_number', doc.registration_number,
               'doc_number', doc.doc_number, 'doc_date', doc.doc_date, 'addressee', doc.addressee,
               'totals', doc.totals, 'storage_path', doc.storage_path, 'file_name', doc.file_name,
               'content_type', doc.content_type, 'sha256', doc.sha256, 'byte_size', doc.byte_size) end)
           order by m.paid, d.day, m.id)
      from public.master_imports m
      cross join lateral (select coalesce(m.document_date, (m.created_at at time zone 'Asia/Tokyo')::date) as day) d
      left join public.import_documents doc on doc.id = m.document_id
      left join public.delivery_suppliers s on s.id = coalesce(m.supplier_id, doc.supplier_id)
      left join public.warehouses w on w.id = m.warehouse_id
     where m.source = 'stock_file' and m.undone_at is null
       and m.status in ('stock_done', 'awaiting_inspection')
       and (case when p_unpaid_only then not m.paid else d.day between p_from and p_to end)), '[]'::jsonb);
end;
$$;
revoke all on function public.payments_list(date, date, boolean) from public, anon;
grant execute on function public.payments_list(date, date, boolean) to authenticated;
