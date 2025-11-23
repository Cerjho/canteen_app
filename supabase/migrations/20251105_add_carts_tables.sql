-- Normalized carts and cart_items tables for cart persistence
CREATE TABLE IF NOT EXISTS carts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  parent_id UUID NOT NULL REFERENCES users(uid) ON DELETE CASCADE,
  student_id UUID REFERENCES students(id) ON DELETE CASCADE,
  cart_type TEXT NOT NULL CHECK (cart_type IN ('daily','weekly')),
  week_id UUID REFERENCES weekly_menus(id) ON DELETE SET NULL,
  order_date DATE,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','checked_out','abandoned')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_carts_parent ON carts(parent_id);
CREATE INDEX IF NOT EXISTS idx_carts_student ON carts(student_id);
CREATE INDEX IF NOT EXISTS idx_carts_type_status ON carts(cart_type, status);

ALTER TABLE carts ENABLE ROW LEVEL SECURITY;

-- Parents can select only their carts
CREATE POLICY "Parents select own carts" ON carts
  FOR SELECT USING (auth.uid() = parent_id);

-- Parents can insert their carts
CREATE POLICY "Parents insert own carts" ON carts
  FOR INSERT WITH CHECK (auth.uid() = parent_id);

-- Parents can update their carts
CREATE POLICY "Parents update own carts" ON carts
  FOR UPDATE USING (auth.uid() = parent_id);

-- Parents can delete their carts (if needed)
CREATE POLICY "Parents delete own carts" ON carts
  FOR DELETE USING (auth.uid() = parent_id);

CREATE TRIGGER update_carts_updated_at BEFORE UPDATE ON carts
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Items
CREATE TABLE IF NOT EXISTS cart_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  cart_id UUID NOT NULL REFERENCES carts(id) ON DELETE CASCADE,
  item_id UUID NOT NULL REFERENCES menu_items(id) ON DELETE CASCADE,
  quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
  added_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cart_items_cart ON cart_items(cart_id);
CREATE INDEX IF NOT EXISTS idx_cart_items_item ON cart_items(item_id);

ALTER TABLE cart_items ENABLE ROW LEVEL SECURITY;

-- Parents can read items of their carts
CREATE POLICY "Parents select own cart items" ON cart_items
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM carts c WHERE c.id = cart_items.cart_id AND c.parent_id = auth.uid()
    )
  );

-- Parents can manage items of their carts
CREATE POLICY "Parents manage own cart items" ON cart_items
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM carts c WHERE c.id = cart_items.cart_id AND c.parent_id = auth.uid()
    )
  ) WITH CHECK (
    EXISTS (
      SELECT 1 FROM carts c WHERE c.id = cart_items.cart_id AND c.parent_id = auth.uid()
    )
  );
