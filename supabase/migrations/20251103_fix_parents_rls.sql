-- Fix RLS policies for parents table to use user_id and allow admin updates
-- Safe/idempotent migration: drops conflicting policies if they exist and recreates correct ones.

-- Ensure RLS is enabled on parents
ALTER TABLE IF EXISTS public.parents ENABLE ROW LEVEL SECURITY;

-- Helper: drop policy if exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' AND tablename = 'parents' AND policyname = 'parents_admin_update'
  ) THEN
    EXECUTE 'DROP POLICY parents_admin_update ON public.parents';
  END IF;
  IF EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' AND tablename = 'parents' AND policyname = 'parents_admin_insert'
  ) THEN
    EXECUTE 'DROP POLICY parents_admin_insert ON public.parents';
  END IF;
  IF EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' AND tablename = 'parents' AND policyname = 'parents_self_select'
  ) THEN
    EXECUTE 'DROP POLICY parents_self_select ON public.parents';
  END IF;
END $$;

-- Optional helper function: is_admin() (only create if missing)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE p.proname = 'is_admin' AND n.nspname = 'public'
  ) THEN
    EXECUTE $$
      CREATE FUNCTION public.is_admin() RETURNS boolean AS $$
      BEGIN
        RETURN coalesce(
          (auth.jwt() -> 'app_metadata' ->> 'is_admin')::boolean,
          false
        );
      END;
      $$ LANGUAGE plpgsql SECURITY DEFINER;
    $$;
  END IF;
END $$;

-- Allow parents to SELECT their own row; admins can read all
CREATE POLICY parents_self_select ON public.parents
FOR SELECT
USING (
  user_id = auth.uid() OR public.is_admin()
);

-- Allow admins to INSERT parent rows
CREATE POLICY parents_admin_insert ON public.parents
FOR INSERT
WITH CHECK (public.is_admin());

-- Allow admins to UPDATE any parent row
CREATE POLICY parents_admin_update ON public.parents
FOR UPDATE
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- NOTE:
-- If you previously had policies using parents.id or id, those would cause 42703 errors
-- because the primary key column is user_id. This migration replaces them.
