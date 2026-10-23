-- 0149: 本 as a unit; a new product counts in the unit its file names.
--
-- Pens, refills and bottles are counted in 本. Until now the unit list had no
-- 本, so every product counted in 個 and the file's 本 was kept only as text
-- (products.unit). This adds 本 and lets a new product take its base unit
-- from that text when it names a counting unit (本, 個, 箱, 枚 ...).
-- Anything else, or no text, stays 個 as before.
--
-- Existing products are not touched here: moving them is a data decision,
-- made per company (see docs/migration_plan.md, 0149).

insert into public.uoms (code, name, uom_type)
values ('HON', '本', 'COUNT')
on conflict (code) do nothing;

create or replace function public.fill_product_base_uom()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if new.base_uom_id is null and nullif(btrim(coalesce(new.unit, '')), '') is not null then
    select id into new.base_uom_id
      from public.uoms
     where is_active and uom_type = 'COUNT'
       and (name = btrim(new.unit) or code = upper(btrim(new.unit)))
     order by id
     limit 1;
  end if;
  if new.base_uom_id is null then
    select id into new.base_uom_id from public.uoms where code = 'PCS';
  end if;
  return new;
end;
$$;
