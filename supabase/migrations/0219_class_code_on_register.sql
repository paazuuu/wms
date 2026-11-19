-- 0219: the 識別コード each line was read with is kept when the file goes
-- in (stock_file_stage, which 予定外の入荷 also goes through, and
-- stock_file_import): p_lines[].class_code.
do $$
declare
  v_def text;
  v_new text;
begin
  v_def := pg_get_functiondef('public.stock_file_stage'::regproc);
  v_new := replace(v_def,
    $a$insert into public.master_import_lines (import_id, line_no, jan_code, product_id, quantity, movement_ids)
    values (v_id, v_no, v_jan, v_product, v_qty, '{}')$a$,
    $a$insert into public.master_import_lines (import_id, line_no, jan_code, product_id, quantity, movement_ids, class_code)
    values (v_id, v_no, v_jan, v_product, v_qty, '{}',
            nullif(left(upper(btrim(coalesce(e->>'class_code', ''))), 20), ''))$a$);
  if v_new = v_def then
    raise exception '0219: stock_file_stage did not change';
  end if;
  execute v_new;

  v_def := pg_get_functiondef('public.stock_file_import'::regproc);
  v_new := replace(v_def,
    $a$(import_id, line_no, jan_code, product_id, quantity, on_hand_before, on_hand_set, added, on_hand_after, movement_ids)
    values (v_id, v_no, v_jan, v_product, v_qty, v_before,
            case when p_mode = 'set' then v_qty end, v_delta, v_before + v_delta,
            array_remove(array[v_m], null))$a$,
    $a$(import_id, line_no, jan_code, product_id, quantity, on_hand_before, on_hand_set, added, on_hand_after, movement_ids,
       class_code)
    values (v_id, v_no, v_jan, v_product, v_qty, v_before,
            case when p_mode = 'set' then v_qty end, v_delta, v_before + v_delta,
            array_remove(array[v_m], null),
            nullif(left(upper(btrim(coalesce(e->>'class_code', ''))), 20), ''))$a$);
  if v_new = v_def then
    raise exception '0219: stock_file_import did not change';
  end if;
  execute v_new;
end $$;
