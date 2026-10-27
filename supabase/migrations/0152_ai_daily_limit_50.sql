-- 0152: 50 AI calls a day to begin with, as asked (0151 began at 300).
-- A PDF or picture read is two calls (the reading and its check).
alter table public.ai_settings alter column daily_limit set default 50;
update public.ai_settings set daily_limit = 50, updated_at = now() where id = 1 and daily_limit = 300;
