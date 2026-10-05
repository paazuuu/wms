-- 0136 — every expected receipt carries its totals (予定 / 入荷済 / 残), kept
-- by the same triggers as its state (0134), so a list of plans can show them
-- without reading every line.

alter table public.delivery_plans
  add column if not exists planned_units integer not null default 0,
  add column if not exists received_units integer not null default 0,
  add column if not exists remaining_units integer not null default 0;

comment on column public.delivery_plans.planned_units is '予定: sum of the planned quantities of the lines.';
comment on column public.delivery_plans.received_units is '入荷済: sum of what every receipt brought for the lines.';
comment on column public.delivery_plans.remaining_units is '残: what the lines still expect, never below zero per line.';

create or replace function public.delivery_plan_dates_and_state()
returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_iso text;
begin
  if tg_op = 'INSERT' then
    if new.expected_arrival_date is null then
      v_iso := substring(coalesce(new.delivery_date, '') from '^\s*(\d{4}-\d{2}-\d{2})');
      if v_iso is not null then
        begin new.expected_arrival_date := v_iso::date; exception when others then null; end;
      end if;
    elsif new.delivery_date is null then
      new.delivery_date := to_char(new.expected_arrival_date, 'YYYY-MM-DD');
    end if;
  else
    if new.expected_arrival_date is distinct from old.expected_arrival_date then
      new.delivery_date := case when new.expected_arrival_date is null then null
                                else to_char(new.expected_arrival_date, 'YYYY-MM-DD') end;
    elsif new.delivery_date is distinct from old.delivery_date then
      v_iso := substring(coalesce(new.delivery_date, '') from '^\s*(\d{4}-\d{2}-\d{2})');
      new.expected_arrival_date := null;
      if v_iso is not null then
        begin new.expected_arrival_date := v_iso::date; exception when others then null; end;
      end if;
    end if;
  end if;
  new.receipt_state := public.compute_receipt_state(new.id, new.status, new.on_hold);
  select coalesce(sum(coalesce(planned_quantity, 0)), 0),
         coalesce(sum(coalesce(received_quantity, 0)), 0),
         coalesce(sum(greatest(coalesce(planned_quantity, 0) - coalesce(received_quantity, 0), 0)), 0)
    into new.planned_units, new.received_units, new.remaining_units
    from public.delivery_plan_lines where delivery_plan_id = new.id;
  return new;
end;
$$;

create or replace function public.delivery_plan_line_state_changed()
returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_plan bigint := coalesce(new.delivery_plan_id, old.delivery_plan_id);
begin
  -- Touching the plan runs its BEFORE trigger, which recomputes the state
  -- and the totals.
  update public.delivery_plans p set receipt_state = p.receipt_state where p.id = v_plan;
  return null;
end;
$$;
