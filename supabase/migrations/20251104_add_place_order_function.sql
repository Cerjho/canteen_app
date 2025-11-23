-- Atomic order placement function: inserts order and deducts parent balance in one transaction
-- Ensures only the authenticated parent (auth.uid()) can place their own orders

CREATE OR REPLACE FUNCTION public.place_order(
  p_parent_id uuid,
  p_student_id uuid,
  p_items jsonb,
  p_total numeric,
  p_delivery_date date,
  p_delivery_time time DEFAULT NULL,
  p_special_instructions text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_balance numeric;
  v_new_balance numeric;
  v_order_id uuid;
  v_order_number text;
BEGIN
  -- Safety: Only allow parent to place their own order
  IF auth.uid() IS NULL OR auth.uid() <> p_parent_id THEN
    RAISE EXCEPTION 'not_allowed';
  END IF;

  -- Lock parent row and check balance
  SELECT balance INTO v_balance
  FROM public.parents
  WHERE user_id = p_parent_id
  FOR UPDATE;

  IF v_balance IS NULL THEN
    RAISE EXCEPTION 'parent_not_found';
  END IF;

  IF p_total IS NULL OR p_total <= 0 THEN
    RAISE EXCEPTION 'invalid_total';
  END IF;

  IF v_balance < p_total THEN
    RAISE EXCEPTION 'insufficient_balance';
  END IF;

  -- Generate order number (timestamp-based)
  v_order_number := 'ORD-' || to_char(NOW(), 'YYYYMMDDHH24MISSMS');

  -- Insert order
  INSERT INTO public.orders(
    order_number,
    parent_id,
    student_id,
    items,
    total_amount,
    status,
    order_type,
    delivery_date,
    delivery_time,
    special_instructions
  ) VALUES (
    v_order_number,
    p_parent_id,
    p_student_id,
    p_items,
    p_total,
    'pending',
    'one-time',
    p_delivery_date,
    p_delivery_time,
    p_special_instructions
  ) RETURNING id INTO v_order_id;

  -- Deduct balance
  v_new_balance := v_balance - p_total;
  UPDATE public.parents
  SET balance = v_new_balance,
      updated_at = NOW()
  WHERE user_id = p_parent_id;

  -- Record transaction (uses current schema columns)
  INSERT INTO public.parent_transactions(
    parent_id,
    type,
    amount,
    balance_before,
    balance_after,
    description,
    reference_id,
    status
  ) VALUES (
    p_parent_id,
    'debit',
    -p_total,
    v_balance,
    v_new_balance,
    'single_order',
    v_order_id::text,
    'completed'
  );

  -- Optionally, insert a transaction record if your schema matches; skipped here due to schema variations
  -- RETURN minimal payload
  RETURN jsonb_build_object(
    'order_id', v_order_id,
    'order_number', v_order_number,
    'balance_after', v_new_balance
  );
END;
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION public.place_order(uuid, uuid, jsonb, numeric, date, time, text) TO authenticated;
