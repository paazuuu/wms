-- 0176: the counts behind システムの初期化 are read only through
-- system_reset_preview (system.reset), not by every signed-in user.
revoke execute on function public.system_reset_counts() from authenticated;
