-- Add policies to allow authenticated users to create their own users and parents rows
-- This fixes registration where normal users couldn't insert into users/parents due to RLS.

-- USERS: allow self-insert (uid must match auth.uid())
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' AND tablename = 'users' AND policyname = 'Users can create own profile'
  ) THEN
    CREATE POLICY "Users can create own profile" ON public.users
      FOR INSERT
      WITH CHECK (auth.uid() = uid);
  END IF;
END $$;

-- PARENTS: allow self-insert (user_id must match auth.uid())
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' AND tablename = 'parents' AND policyname = 'Parents can create own profile'
  ) THEN
    CREATE POLICY "Parents can create own profile" ON public.parents
      FOR INSERT
      WITH CHECK (auth.uid() = user_id);
  END IF;
END $$;

-- Optional: ensure RLS is enabled (safe if already enabled)
ALTER TABLE IF EXISTS public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.parents ENABLE ROW LEVEL SECURITY;
