-- 0196: a product's stock history (0145/0188) says which receipts were 予定外の
-- 入荷 and where their invoice stands, so a 「請求書なしで完了」 pressed by
-- mistake is seen when looking back: import_kind, no_invoice_reason and
-- invoice_state ('waiting' 請求書待ち, 'invoiced' 請求書あり, 'none' 請求書なし)
-- for each movement from an unplanned receipt.

do $$
declare
  v_def text;
  v_new text;
begin
  select pg_get_functiondef('public.product_stock_history(bigint, bigint, integer)'::regprocedure) into v_def;
  if position('invoice_state' in v_def) > 0 then
    raise notice 'product_stock_history: no change';
    return;
  end if;
  v_new := replace(v_def,
    'mi.id as import_id, coalesce(mi.original_name, ob.file_name) as file_name, mi.source,',
    'mi.id as import_id, coalesce(mi.original_name, ob.file_name) as file_name, mi.source, '
    || 'mi.kind as import_kind, mi.no_invoice_reason, mi.no_invoice_at, '
    || '(select count(*) from public.master_import_lines il where il.import_id = mi.id '
    || 'and il.invoiced_import_id is not null) as invoiced_lines,');
  v_new := replace(v_new,
    '''import_id'', import_id, ''file_name'', file_name)',
    '''import_id'', import_id, ''file_name'', file_name, ''import_kind'', import_kind, '
    || '''no_invoice_reason'', no_invoice_reason, ''invoice_state'', case when import_kind = ''unplanned'' then '
    || 'case when no_invoice_at is not null then ''none'' when invoiced_lines > 0 then ''invoiced'' '
    || 'else ''waiting'' end end)');
  if v_new = v_def or position('invoice_state' in v_new) = 0 or position('invoiced_lines,' in v_new) = 0 then
    raise exception 'product_stock_history: the text to change was not found';
  end if;
  execute v_new;
end $$;
