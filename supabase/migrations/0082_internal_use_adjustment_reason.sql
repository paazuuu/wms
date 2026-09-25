-- Stock consumed by the company itself — samples handed to a customer,
-- materials used in-house, staff use — is neither DAMAGE, LOSS, FOUND,
-- CORRECTION, RETURN nor really OTHER: it is stock that left on purpose, for
-- a reason worth telling apart from "broken" or "missing" when someone reads
-- the adjustment history back. 0017's own reason vocabulary had no code for
-- it, so it always fell into OTHER with the honest use hidden in free text.

alter table public.stock_adjustments drop constraint stock_adjustments_reason_check;
alter table public.stock_adjustments add constraint stock_adjustments_reason_check
  check (reason in (
    'DAMAGE',        -- broken / unsellable
    'LOSS',          -- missing, unexplained
    'FOUND',         -- turned up
    'CORRECTION',    -- data entry fix
    'RETURN',        -- customer return back into stock
    'INTERNAL_USE',  -- consumed by the company itself, not shipped to a customer
    'OTHER'
  ));
