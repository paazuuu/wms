-- 0218: 識別コード on the lines of an order file, the 入出庫履歴 by date
-- (JST) with that code and the memo of the upload, a category tree for
-- products, and 仕入先回答 kept with 入荷希望リスト.

------------------------------------------------------------------------
-- 1. 識別コード (class code)
--
-- Suppliers print a short code beside each line (HL, BL, BH …) that groups
-- what they sell. It is read with the lines, kept on each line of the
-- order file, and can be filled in by hand later, many lines at once.
------------------------------------------------------------------------
alter table public.master_import_lines add column if not exists class_code text;
create index if not exists master_import_lines_class_code on public.master_import_lines (class_code)
  where class_code is not null;
create index if not exists master_import_lines_product_code on public.master_import_lines (product_id)
  where class_code is not null;

-- p_codes: [{line_no, class_code}] — an empty code takes it off.
create or replace function public.stock_file_set_class_codes(p_import_id bigint, p_codes jsonb)
returns integer language plpgsql security definer set search_path = '' as $$
declare
  v_wh bigint;
  v_n integer := 0;
  v_rows integer;
  v_e jsonb;
  v_code text;
begin
  if not (public.has_permission('inventory.adjust') or public.has_permission('product.manage')) then
    raise exception 'not permitted: inventory.adjust required';
  end if;
  select warehouse_id into v_wh from public.master_imports where id = p_import_id;
  if not found then
    raise exception 'import % not found', p_import_id;
  end if;
  if v_wh is not null and not public.can_access_warehouse(v_wh) then
    raise exception 'not permitted: warehouse.scope required';
  end if;
  for v_e in select value from jsonb_array_elements(coalesce(p_codes, '[]'::jsonb)) loop
    v_code := nullif(upper(btrim(coalesce(v_e->>'class_code', ''))), '');
    if v_code is not null and length(v_code) > 20 then
      raise exception 'class_code_too_long';
    end if;
    update public.master_import_lines
       set class_code = v_code
     where import_id = p_import_id
       and line_no = (v_e->>'line_no')::integer
       and class_code is distinct from v_code;
    get diagnostics v_rows = row_count;
    v_n := v_n + v_rows;
  end loop;
  if v_n > 0 then
    perform public.log_audit('stock_file.class_codes', 'master_import', p_import_id::text, v_wh,
      jsonb_build_object('lines', v_n));
  end if;
  return v_n;
end;
$$;
grant execute on function public.stock_file_set_class_codes(bigint, jsonb) to authenticated, service_role;
revoke execute on function public.stock_file_set_class_codes(bigint, jsonb) from public, anon;

-- The code a product was last delivered under (by its id, else its JAN).
create or replace function public.product_latest_class_code(p_product_id bigint, p_jan text default null)
returns text language sql stable security definer set search_path = '' as $$
  select l.class_code
    from public.master_import_lines l
    join public.master_imports i on i.id = l.import_id
   where l.class_code is not null
     and i.undone_at is null
     and ((p_product_id is not null and l.product_id = p_product_id)
          or (p_product_id is null and p_jan is not null and l.jan_code = p_jan))
   order by i.created_at desc, l.line_no
   limit 1;
$$;
grant execute on function public.product_latest_class_code(bigint, text) to authenticated, service_role;
revoke execute on function public.product_latest_class_code(bigint, text) from public, anon;

-- The codes in use, for a pick list: each with how many lines carry it.
create or replace function public.class_codes_in_use()
returns jsonb language sql stable security definer set search_path = '' as $$
  select case when public.has_permission('report.view') or public.master_import_viewer() then coalesce((
    select jsonb_agg(jsonb_build_object('code', code, 'lines', n) order by code)
      from (select l.class_code as code, count(*) as n
              from public.master_import_lines l
              join public.master_imports i on i.id = l.import_id
             where l.class_code is not null and i.undone_at is null
             group by l.class_code) c), '[]'::jsonb)
  else '[]'::jsonb end;
$$;
grant execute on function public.class_codes_in_use() to authenticated, service_role;
revoke execute on function public.class_codes_in_use() from public, anon;

-- The memos written when files were taken in, newest first, for a pick list.
create or replace function public.stock_import_notes()
returns jsonb language sql stable security definer set search_path = '' as $$
  select case when public.has_permission('report.view') or public.master_import_viewer() then coalesce((
    select jsonb_agg(note order by last desc)
      from (select btrim(note) as note, max(created_at) as last
              from public.master_imports
             where coalesce(btrim(note), '') <> '' and undone_at is null
             group by btrim(note)
             order by max(created_at) desc
             limit 300) n), '[]'::jsonb)
  else '[]'::jsonb end;
$$;
grant execute on function public.stock_import_notes() to authenticated, service_role;
revoke execute on function public.stock_import_notes() from public, anon;

-- The import's lines say their code.
do $$
declare
  v_def text := pg_get_functiondef('public.master_import_detail(bigint, bigint)'::regprocedure);
  v_new text;
begin
  v_new := replace(v_def,
    $a$'invoiced_import_id', l.invoiced_import_id, 'not_delivered', l.not_delivered,$a$,
    $a$'invoiced_import_id', l.invoiced_import_id, 'not_delivered', l.not_delivered,
             'class_code', l.class_code, 'category', p.category,$a$);
  if v_new = v_def then
    raise exception '0218: master_import_detail did not change';
  end if;
  execute v_new;
end $$;

------------------------------------------------------------------------
-- 2. 入出庫履歴: the day (JST, no time), the 識別コード, the memo and the
-- supplier of the upload the stock came in with; filtered by code, memo
-- and JST days.
------------------------------------------------------------------------
do $$
declare
  v_def text := pg_get_functiondef('public.run_report(text, jsonb, integer)'::regprocedure);
  v_new text := v_def;
begin
  v_new := replace(v_new,
    $a$  v_scope bigint[] := public.accessible_warehouse_ids();$a$,
    $a$  v_scope bigint[] := public.accessible_warehouse_ids();
  v_class_code text := nullif(upper(btrim(coalesce(p_filters->>'class_code', ''))), '');
  v_note text := nullif(btrim(coalesce(p_filters->>'note', '')), '');
  v_day_from date := nullif(p_filters->>'day_from', '')::date;
  v_day_to date := nullif(p_filters->>'day_to', '')::date;$a$);
  v_new := replace(v_new,
    $a$               m.quantity_after, m.created_at, w.country_code
          from public.stock_movements m
          left join public.warehouses w on w.id = m.warehouse_id
         where (v_warehouse_id is null or m.warehouse_id = v_warehouse_id)$a$,
    $a$               m.quantity_after,
               to_char(m.created_at at time zone 'Asia/Tokyo', 'YYYY-MM-DD') as movement_date,
               w.country_code,
               x.class_code, x.import_note, x.import_supplier
          from public.stock_movements m
          left join public.warehouses w on w.id = m.warehouse_id
          left join lateral (
            select coalesce(
                     (select l.class_code from public.master_import_lines l
                       where i.id is not null and l.import_id = i.id and l.class_code is not null
                         and (l.product_id = m.product_id or l.jan_code = m.jan_code)
                       order by l.line_no limit 1),
                     public.product_latest_class_code(m.product_id, m.jan_code)) as class_code,
                   nullif(btrim(i.note), '') as import_note,
                   coalesce(s.name, i.note_supplier) as import_supplier
              from (select 1) one
              left join public.master_imports i
                on m.reference_type = 'master_import' and m.reference_id ~ '^[0-9]+$'
               and i.id = m.reference_id::bigint
              left join public.delivery_suppliers s on s.id = i.supplier_id
          ) x on true
         where (v_warehouse_id is null or m.warehouse_id = v_warehouse_id)
           and (v_class_code is null or x.class_code = v_class_code)
           and (v_note is null or strpos(lower(coalesce(x.import_note, '')), lower(v_note)) > 0)
           and (v_day_from is null or (m.created_at at time zone 'Asia/Tokyo')::date >= v_day_from)
           and (v_day_to is null or (m.created_at at time zone 'Asia/Tokyo')::date <= v_day_to)$a$);
  if v_new = v_def or strpos(v_new, 'movement_date') = 0 or strpos(v_new, 'v_day_from date') = 0 then
    raise exception '0218: run_report did not change as expected';
  end if;
  execute v_new;
end $$;

------------------------------------------------------------------------
-- 3. 商品カテゴリー: a tree of any depth (文房具 > ペン > ボールペン > 水性 …).
-- Each product points at one node; products.category keeps the path as
-- words ("文房具 > ペン > ボールペン") for the lists and reports that read it.
------------------------------------------------------------------------
create table if not exists public.product_categories (
  id bigint generated always as identity primary key,
  parent_id bigint references public.product_categories (id),
  name text not null check (length(btrim(name)) between 1 and 60),
  created_at timestamptz not null default now(),
  created_by uuid
);
create unique index if not exists product_categories_name_uq
  on public.product_categories (coalesce(parent_id, 0), lower(btrim(name)));
create index if not exists product_categories_parent on public.product_categories (parent_id);
alter table public.product_categories enable row level security;
do $$
begin
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'product_categories'
                 and policyname = 'product_categories: viewers read') then
    create policy "product_categories: viewers read" on public.product_categories
      for select to authenticated
      using (public.has_permission('product.view') or public.has_permission('product.manage'));
  end if;
end $$;

alter table public.products
  add column if not exists category_id bigint references public.product_categories (id),
  add column if not exists category_source text check (category_source in ('ai', 'manual')),
  add column if not exists category_set_at timestamptz;
create index if not exists products_category_id on public.products (category_id);

-- From the top down to [p_id].
create or replace function public.product_category_path(p_id bigint)
returns text[] language sql stable security definer set search_path = '' as $$
  with recursive up as (
    select id, parent_id, name, 0 as depth from public.product_categories where id = p_id
    union all
    select c.id, c.parent_id, c.name, up.depth + 1
      from public.product_categories c join up on c.id = up.parent_id
     where up.depth < 30
  )
  select coalesce(array_agg(name order by depth desc), '{}') from up;
$$;
grant execute on function public.product_category_path(bigint) to authenticated, service_role;
revoke execute on function public.product_category_path(bigint) from public, anon;

-- The node for [p_path], made where missing: names trimmed, empty steps
-- left out, at most 12 deep. Null for an empty path.
create or replace function public.product_category_ensure(p_path text[])
returns bigint language plpgsql security definer set search_path = '' as $$
declare
  v_parent bigint := null;
  v_id bigint;
  v_name text;
  v_depth integer := 0;
begin
  if not public.has_permission('product.manage') then
    raise exception 'not permitted: product.manage required';
  end if;
  foreach v_name in array coalesce(p_path, '{}'::text[]) loop
    v_name := btrim(regexp_replace(coalesce(v_name, ''), '\s+', ' ', 'g'));
    continue when v_name = '';
    v_depth := v_depth + 1;
    exit when v_depth > 12;
    v_name := left(v_name, 60);
    select id into v_id from public.product_categories
     where coalesce(parent_id, 0) = coalesce(v_parent, 0) and lower(btrim(name)) = lower(v_name);
    if v_id is null then
      insert into public.product_categories (parent_id, name, created_by)
      values (v_parent, v_name, auth.uid())
      on conflict (coalesce(parent_id, 0), lower(btrim(name))) do nothing
      returning id into v_id;
      if v_id is null then
        select id into v_id from public.product_categories
         where coalesce(parent_id, 0) = coalesce(v_parent, 0) and lower(btrim(name)) = lower(v_name);
      end if;
    end if;
    v_parent := v_id;
    v_id := null;
  end loop;
  return v_parent;
end;
$$;
grant execute on function public.product_category_ensure(text[]) to authenticated, service_role;
revoke execute on function public.product_category_ensure(text[]) from public, anon;

-- A product's category set from its path; an empty path takes it off.
-- The AI's never replaces a person's.
create or replace function public.product_set_category(p_product_id bigint, p_path text[], p_source text default 'manual')
returns boolean language plpgsql security definer set search_path = '' as $$
declare
  v_id bigint;
  v_src text := case when p_source = 'ai' then 'ai' else 'manual' end;
  v_old text;
begin
  if not public.has_permission('product.manage') then
    raise exception 'not permitted: product.manage required';
  end if;
  select category_source into v_old from public.products where id = p_product_id;
  if not found then
    raise exception 'product % not found', p_product_id;
  end if;
  if v_src = 'ai' and v_old = 'manual' then
    return false;
  end if;
  v_id := public.product_category_ensure(p_path);
  update public.products
     set category_id = v_id,
         category = case when v_id is null then null
                         else array_to_string(public.product_category_path(v_id), ' > ') end,
         category_source = case when v_id is null then null else v_src end,
         category_set_at = now(),
         updated_at = now()
   where id = p_product_id;
  return true;
end;
$$;
grant execute on function public.product_set_category(bigint, text[], text) to authenticated, service_role;
revoke execute on function public.product_set_category(bigint, text[], text) from public, anon;

-- The AI's categories, by JAN or product id: p [{jan?, product_id?, path: [...]}].
-- Taken only by products with no category or the AI's own. Returns how many.
create or replace function public.product_categories_apply(p jsonb)
returns integer language plpgsql security definer set search_path = '' as $$
declare
  v_e jsonb;
  v_path text[];
  v_pid bigint;
  v_n integer := 0;
begin
  if not public.has_permission('product.manage') then
    raise exception 'not permitted: product.manage required';
  end if;
  for v_e in select value from jsonb_array_elements(coalesce(p, '[]'::jsonb)) loop
    select coalesce(array_agg(btrim(x) order by o), '{}') into v_path
      from jsonb_array_elements_text(coalesce(v_e->'path', '[]'::jsonb)) with ordinality t(x, o)
     where btrim(x) <> '';
    continue when coalesce(array_length(v_path, 1), 0) = 0;
    for v_pid in
      select id from public.products
       where (nullif(v_e->>'product_id', '') is not null and id = (v_e->>'product_id')::bigint)
          or (nullif(v_e->>'product_id', '') is null and nullif(v_e->>'jan', '') is not null and jan_code = v_e->>'jan')
    loop
      if (select coalesce(category_source, 'ai') = 'ai' from public.products where id = v_pid) then
        perform public.product_set_category(v_pid, v_path, 'ai');
        v_n := v_n + 1;
      end if;
    end loop;
  end loop;
  return v_n;
end;
$$;
grant execute on function public.product_categories_apply(jsonb) to authenticated, service_role;
revoke execute on function public.product_categories_apply(jsonb) from public, anon;

-- Every node with its path and how many products sit in it and under it.
create or replace function public.product_category_tree()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not (public.has_permission('product.view') or public.has_permission('product.manage')) then
    return '[]'::jsonb;
  end if;
  return coalesce((
    with recursive t as (
      select c.id, c.parent_id, c.name, array[c.name] as path, array[c.id] as ids
        from public.product_categories c where c.parent_id is null
      union all
      select c.id, c.parent_id, c.name, t.path || c.name, t.ids || c.id
        from public.product_categories c join t on c.parent_id = t.id
       where array_length(t.path, 1) < 30
    )
    select jsonb_agg(jsonb_build_object(
             'id', t.id, 'parent_id', t.parent_id, 'name', t.name, 'path', to_jsonb(t.path),
             'products', (select count(*) from public.products p where p.category_id = t.id),
             'total', (select count(*) from public.products p join t t2 on t2.id = p.category_id
                        where t.id = any(t2.ids)))
           order by array_to_string(t.path, ' > '))
      from t), '[]'::jsonb);
end;
$$;
grant execute on function public.product_category_tree() to authenticated, service_role;
revoke execute on function public.product_category_tree() from public, anon;

-- A node renamed (its products' path words follow).
create or replace function public.product_category_rename(p_id bigint, p_name text)
returns boolean language plpgsql security definer set search_path = '' as $$
declare
  v_name text := left(btrim(regexp_replace(coalesce(p_name, ''), '\s+', ' ', 'g')), 60);
begin
  if not public.has_permission('product.manage') then
    raise exception 'not permitted: product.manage required';
  end if;
  if v_name = '' then
    raise exception 'category_name_required';
  end if;
  update public.product_categories set name = v_name where id = p_id;
  if not found then
    raise exception 'category % not found', p_id;
  end if;
  with recursive down as (
    select id from public.product_categories where id = p_id
    union all
    select c.id from public.product_categories c join down on c.parent_id = down.id
  )
  update public.products p
     set category = array_to_string(public.product_category_path(p.category_id), ' > '), updated_at = now()
   where p.category_id in (select id from down);
  return true;
end;
$$;
grant execute on function public.product_category_rename(bigint, text) to authenticated, service_role;
revoke execute on function public.product_category_rename(bigint, text) from public, anon;

------------------------------------------------------------------------
-- 4. 仕入先回答: what suppliers answer to a wish list — what they can
-- supply, how many and by when — kept as files with a memo, by supplier
-- and, when it answers one, by list. Seen and kept by whoever may see and
-- edit 入荷希望リスト.
------------------------------------------------------------------------
create table if not exists public.supplier_answers (
  id bigint generated always as identity primary key,
  supplier_id bigint,
  supplier_name text,
  request_id bigint,
  answered_on date,
  title text,
  note text,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  removed_at timestamptz,
  removed_by uuid
);
create index if not exists supplier_answers_open on public.supplier_answers (answered_on desc) where removed_at is null;
alter table public.supplier_answers enable row level security;

create table if not exists public.supplier_answer_files (
  id bigint generated always as identity primary key,
  answer_id bigint not null references public.supplier_answers (id),
  storage_path text not null,
  file_name text not null,
  content_type text,
  byte_size bigint,
  created_at timestamptz not null default now(),
  created_by uuid,
  removed_at timestamptz,
  removed_by uuid
);
create index if not exists supplier_answer_files_answer on public.supplier_answer_files (answer_id) where removed_at is null;
alter table public.supplier_answer_files enable row level security;

insert into storage.buckets (id, name, public, file_size_limit)
values ('supplier-answers', 'supplier-answers', false, 26214400)
on conflict (id) do nothing;

-- [p_name]: <answer id>/<file>.
create or replace function public.supplier_answer_file_allowed(p_name text, p_write boolean)
returns boolean language sql stable security definer set search_path = '' as $$
  select split_part(coalesce(p_name, ''), '/', 1) ~ '^[0-9]+$'
     and exists (select 1 from public.supplier_answers a
                  where a.id = split_part(p_name, '/', 1)::bigint and a.removed_at is null)
     and case when p_write then public.purchase_request_can_edit() else public.purchase_request_can_view() end;
$$;
grant execute on function public.supplier_answer_file_allowed(text, boolean) to authenticated, service_role;
revoke execute on function public.supplier_answer_file_allowed(text, boolean) from public, anon;

do $$
begin
  if not exists (select 1 from pg_policies where schemaname = 'storage' and policyname = 'supplier-answers: editors upload') then
    create policy "supplier-answers: editors upload" on storage.objects
      for insert to authenticated
      with check (bucket_id = 'supplier-answers' and public.supplier_answer_file_allowed(name, true));
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'storage' and policyname = 'supplier-answers: viewers read') then
    create policy "supplier-answers: viewers read" on storage.objects
      for select to authenticated
      using (bucket_id = 'supplier-answers' and public.supplier_answer_file_allowed(name, false));
  end if;
end $$;

-- The answers kept, newest first, with their files and the list each answers.
create or replace function public.supplier_answers_list()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.purchase_request_can_view() then
    raise exception 'not permitted: purchase_request.view required';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', a.id, 'supplier_id', a.supplier_id,
             'supplier_name', coalesce(s.name, a.supplier_name),
             'request_id', a.request_id, 'request_number', r.request_number,
             'request_label', coalesce(r.customer_name, r.title),
             'answered_on', a.answered_on, 'title', a.title, 'note', a.note,
             'created_at', a.created_at, 'updated_at', a.updated_at,
             'created_by_name', (select coalesce(u.name, u.email) from public.app_users u where u.id = a.created_by),
             'files', coalesce((select jsonb_agg(jsonb_build_object(
                          'id', f.id, 'file_name', f.file_name, 'storage_path', f.storage_path,
                          'content_type', f.content_type, 'byte_size', f.byte_size, 'created_at', f.created_at)
                        order by f.id)
                        from public.supplier_answer_files f where f.answer_id = a.id and f.removed_at is null), '[]'::jsonb))
           order by coalesce(a.answered_on, a.created_at::date) desc, a.id desc)
      from public.supplier_answers a
      left join public.delivery_suppliers s on s.id = a.supplier_id
      left join public.purchase_requests r on r.id = a.request_id
     where a.removed_at is null), '[]'::jsonb);
end;
$$;
grant execute on function public.supplier_answers_list() to authenticated, service_role;
revoke execute on function public.supplier_answers_list() from public, anon;

-- p: {id?, supplier_id?, supplier_name?, request_id?, answered_on?, title?, note?}. Its id.
create or replace function public.supplier_answer_save(p jsonb)
returns bigint language plpgsql security definer set search_path = '' as $$
declare
  v_id bigint := nullif(p->>'id', '')::bigint;
  v_sup bigint := nullif(p->>'supplier_id', '')::bigint;
  v_name text := nullif(btrim(coalesce(p->>'supplier_name', '')), '');
begin
  if not public.purchase_request_can_edit() then
    raise exception 'not permitted: purchase_request.manage required';
  end if;
  if v_sup is null and v_name is null then
    raise exception 'supplier_answer_supplier_required';
  end if;
  if v_id is null then
    insert into public.supplier_answers (supplier_id, supplier_name, request_id, answered_on, title, note,
                                         created_by, updated_by)
    values (v_sup, v_name, nullif(p->>'request_id', '')::bigint,
            coalesce(nullif(p->>'answered_on', '')::date, (now() at time zone 'Asia/Tokyo')::date),
            nullif(btrim(coalesce(p->>'title', '')), ''), nullif(btrim(coalesce(p->>'note', '')), ''),
            auth.uid(), auth.uid())
    returning id into v_id;
  else
    update public.supplier_answers
       set supplier_id = v_sup, supplier_name = v_name,
           request_id = nullif(p->>'request_id', '')::bigint,
           answered_on = coalesce(nullif(p->>'answered_on', '')::date, answered_on),
           title = nullif(btrim(coalesce(p->>'title', '')), ''),
           note = nullif(btrim(coalesce(p->>'note', '')), ''),
           updated_at = now(), updated_by = auth.uid()
     where id = v_id and removed_at is null;
    if not found then
      raise exception 'supplier answer % not found', v_id;
    end if;
  end if;
  return v_id;
end;
$$;
grant execute on function public.supplier_answer_save(jsonb) to authenticated, service_role;
revoke execute on function public.supplier_answer_save(jsonb) from public, anon;

create or replace function public.supplier_answer_remove(p_id bigint)
returns boolean language plpgsql security definer set search_path = '' as $$
begin
  if not public.purchase_request_can_edit() then
    raise exception 'not permitted: purchase_request.manage required';
  end if;
  update public.supplier_answers set removed_at = now(), removed_by = auth.uid()
   where id = p_id and removed_at is null;
  return found;
end;
$$;
grant execute on function public.supplier_answer_remove(bigint) to authenticated, service_role;
revoke execute on function public.supplier_answer_remove(bigint) from public, anon;

create or replace function public.supplier_answer_file_add(p_answer_id bigint, p_path text, p_name text,
                                                           p_type text default null, p_size bigint default null)
returns bigint language plpgsql security definer set search_path = '' as $$
declare
  v_id bigint;
begin
  if not public.purchase_request_can_edit() then
    raise exception 'not permitted: purchase_request.manage required';
  end if;
  if not exists (select 1 from public.supplier_answers where id = p_answer_id and removed_at is null) then
    raise exception 'supplier answer % not found', p_answer_id;
  end if;
  if split_part(coalesce(p_path, ''), '/', 1) <> p_answer_id::text then
    raise exception 'supplier_answer_file_path';
  end if;
  insert into public.supplier_answer_files (answer_id, storage_path, file_name, content_type, byte_size, created_by)
  values (p_answer_id, p_path, coalesce(nullif(btrim(p_name), ''), p_path), p_type, p_size, auth.uid())
  returning id into v_id;
  return v_id;
end;
$$;
grant execute on function public.supplier_answer_file_add(bigint, text, text, text, bigint) to authenticated, service_role;
revoke execute on function public.supplier_answer_file_add(bigint, text, text, text, bigint) from public, anon;

create or replace function public.supplier_answer_file_remove(p_id bigint)
returns boolean language plpgsql security definer set search_path = '' as $$
begin
  if not public.purchase_request_can_edit() then
    raise exception 'not permitted: purchase_request.manage required';
  end if;
  update public.supplier_answer_files set removed_at = now(), removed_by = auth.uid()
   where id = p_id and removed_at is null;
  return found;
end;
$$;
grant execute on function public.supplier_answer_file_remove(bigint) to authenticated, service_role;
revoke execute on function public.supplier_answer_file_remove(bigint) from public, anon;
