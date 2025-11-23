-- Add RLS write policies for weekly_menu_analytics so admin clients can upsert/delete
-- Requires custom_access_token_hook to set auth.jwt()->>'is_admin'

-- Ensure RLS is enabled (safe if already enabled)
ALTER TABLE IF EXISTS weekly_menu_analytics ENABLE ROW LEVEL SECURITY;

-- Allow admins to INSERT analytics rows
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'weekly_menu_analytics' AND policyname = 'Admins can insert analytics'
  ) THEN
    CREATE POLICY "Admins can insert analytics" ON weekly_menu_analytics
      FOR INSERT WITH CHECK (
        COALESCE((auth.jwt()->>'is_admin')::boolean, false) = true
      );
  END IF;
END$$;

-- Allow admins to UPDATE analytics rows
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'weekly_menu_analytics' AND policyname = 'Admins can update analytics'
  ) THEN
    CREATE POLICY "Admins can update analytics" ON weekly_menu_analytics
      FOR UPDATE USING (
        COALESCE((auth.jwt()->>'is_admin')::boolean, false) = true
      ) WITH CHECK (
        COALESCE((auth.jwt()->>'is_admin')::boolean, false) = true
      );
  END IF;
END$$;

-- Allow admins to DELETE analytics rows (optional, used by deleteAnalytics)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'weekly_menu_analytics' AND policyname = 'Admins can delete analytics'
  ) THEN
    CREATE POLICY "Admins can delete analytics" ON weekly_menu_analytics
      FOR DELETE USING (
        COALESCE((auth.jwt()->>'is_admin')::boolean, false) = true
      );
  END IF;
END$$;
