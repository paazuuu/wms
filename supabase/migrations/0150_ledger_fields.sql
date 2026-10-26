-- 0150: the fields of a purchase ledger (明細) that a reading had no place for.
--
-- A ledger row has: 発注日, 入荷日, 番号, 仕入先, メーカー, 品番, JAN, 数量,
-- 定価(税抜), 単価(税抜), 単価(税込), 金額, 注番. Five of these had no field:
--   delivery_date   入荷日・納品日 (the order date is order_date)
--   serial          the document's own number for the line (番号・序番)
--   supplier        the supplier named on the line itself
--   unit_price_tax  単価(税込), beside unit_price (税抜)
--   order_number    注番・注文番号
-- Headings for them, and the Chinese headings such a ledger uses for the
-- fields we had, are known from now on.

insert into public.document_fields (key, sort_order, description) values
  ('serial', 5, '番号・序番（書類の行の番号）'),
  ('supplier', 8, '仕入先（行ごとに書かれた仕入先名）'),
  ('unit_price_tax', 82, '単価（税込）'),
  ('delivery_date', 112, '入荷日・納品日'),
  ('order_number', 115, '注番・注文番号')
on conflict (key) do nothing;

insert into public.column_aliases (partner_id, header_raw, header_key, field, source)
select null, h, public.normalize_product_text(h), f, 'seed'
  from (values
    -- 明細 (Chinese headings)
    ('下单时间', 'order_date'), ('下单日期', 'order_date'), ('订购日期', 'order_date'),
    ('到货时间', 'delivery_date'), ('到货日期', 'delivery_date'),
    ('编号', 'serial'), ('序号', 'serial'),
    ('供货商', 'supplier'), ('供应商', 'supplier'),
    ('品牌', 'maker'), ('厂家', 'maker'),
    ('零售价（税拔）', 'list_price'), ('零售价', 'list_price'),
    ('单价（税前）', 'unit_price'), ('单价', 'unit_price'),
    ('单价（税入）', 'unit_price_tax'), ('单价（含税）', 'unit_price_tax'),
    ('合计', 'amount'), ('金额', 'amount'),
    ('注番', 'order_number'), ('订单号', 'order_number'),
    -- The same in Japanese
    ('発注日', 'order_date'), ('注文日', 'order_date'),
    ('入荷日', 'delivery_date'), ('納品日', 'delivery_date'), ('着荷日', 'delivery_date'), ('到着日', 'delivery_date'),
    ('序番', 'serial'), ('番号', 'serial'),
    ('仕入先', 'supplier'), ('仕入先名', 'supplier'), ('供給元', 'supplier'),
    ('単価（税込）', 'unit_price_tax'), ('税込単価', 'unit_price_tax'),
    ('単価（税抜）', 'unit_price'), ('税抜単価', 'unit_price'),
    ('定価（税抜）', 'list_price'),
    ('注文番号', 'order_number'), ('注文No', 'order_number'), ('発注番号', 'order_number'), ('オーダー番号', 'order_number')
  ) s(h, f)
on conflict (coalesce(partner_id, 0), header_key) do nothing;
