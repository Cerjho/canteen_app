-- Saved carts for persistence of daily and weekly carts per parent
CREATE TABLE IF NOT EXISTS saved_carts (
  parent_id UUID PRIMARY KEY REFERENCES users(uid) ON DELETE CASCADE,
  daily_cart JSONB NOT NULL DEFAULT '[]',
  weekly_cart JSONB NOT NULL DEFAULT '{}',
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE saved_carts ENABLE ROW LEVEL SECURITY;

-- Parents can read their own saved carts
CREATE POLICY "Parents can view own saved carts" ON saved_carts
  FOR SELECT USING (auth.uid() = parent_id);

-- Parents can upsert their own saved carts
CREATE POLICY "Parents can upsert own saved carts" ON saved_carts
  FOR INSERT WITH CHECK (auth.uid() = parent_id);

CREATE POLICY "Parents can update own saved carts" ON saved_carts
  FOR UPDATE USING (auth.uid() = parent_id);

-- Keep updated_at in sync
CREATE TRIGGER update_saved_carts_updated_at BEFORE UPDATE ON saved_carts
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
