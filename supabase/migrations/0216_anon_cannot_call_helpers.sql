-- 0216: the helpers and actions below ran with their owner's rights and
-- were open to anyone holding the public (anon) key, signed in or not.
-- Each checks permissions inside, so nothing could be changed, but
-- user_display_name told a user's name and e-mail address to anyone who
-- knew their id. They are kept for signed-in people (and the server's
-- own functions) only. my_access and my_roles stay open: signed out they
-- answer "nobody".
do $$
declare
  v_sig text;
begin
  for v_sig in
    select p.oid::regprocedure::text
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.proname in (
         'can_inspect_stock_files', 'can_mark_products', 'can_post_outbound', 'can_record_payments',
         'can_view_outbound', 'can_view_purchase_books', 'can_view_purchase_prices', 'can_write_shelf_notes',
         'cost_evidence_allowed', 'memo_file_allowed', 'note_file_allowed', 'outbound_file_allowed',
         'remove_shelf_note', 'save_shelf_note', 'set_product_marks', 'supplier_cards',
         'supplier_history_viewer', 'supplier_purchase_history', 'user_display_name')
  loop
    execute format('grant execute on function %s to authenticated, service_role', v_sig);
    execute format('revoke execute on function %s from public, anon', v_sig);
  end loop;
end $$;
