-- Allow importing students without linked parents
-- Make parent_user_id nullable; FK (if present) will still enforce validity when set
ALTER TABLE IF EXISTS public.students
  ALTER COLUMN parent_user_id DROP NOT NULL;

-- Optional: ensure no default is set that could inject empty strings
ALTER TABLE IF EXISTS public.students
  ALTER COLUMN parent_user_id DROP DEFAULT;

-- Note: RLS policies should already allow admin inserts. If inserts are still blocked,
-- add an admin-only insert policy like:
-- CREATE POLICY students_admin_insert ON public.students
--   FOR INSERT TO authenticated
--   USING (auth.jwt() ->> 'is_admin' = 'true')
--   WITH CHECK (auth.jwt() ->> 'is_admin' = 'true');
