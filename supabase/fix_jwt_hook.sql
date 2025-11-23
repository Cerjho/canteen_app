-- ============================================================================
-- FIX JWT HOOK FUNCTION
-- ============================================================================
-- This fixes the "Error running hook URI" error
-- Run this in Supabase SQL Editor to update the function
-- ============================================================================

DROP FUNCTION IF EXISTS public.custom_access_token_hook(jsonb);

CREATE OR REPLACE FUNCTION public.custom_access_token_hook(event jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  claims jsonb;
  user_is_admin boolean;
BEGIN
  -- Initialize claims from event
  claims := event->'claims';
  
  -- Safely fetch the is_admin flag from users table
  -- Use COALESCE to default to false if user doesn't exist yet
  BEGIN
    SELECT COALESCE(is_admin, false) INTO user_is_admin
    FROM public.users
    WHERE uid = (event->>'user_id')::uuid;
  EXCEPTION
    WHEN OTHERS THEN
      -- If any error occurs, default to false (non-admin)
      user_is_admin := false;
  END;

  -- If no user record found, default to false
  IF user_is_admin IS NULL THEN
    user_is_admin := false;
  END IF;

  -- Set the claim in the token
  claims := jsonb_set(claims, '{is_admin}', to_jsonb(user_is_admin));

  -- Update the event object with new claims
  event := jsonb_set(event, '{claims}', claims);

  RETURN event;
EXCEPTION
  WHEN OTHERS THEN
    -- If anything fails, return the original event unchanged
    -- This prevents authentication from breaking
    RETURN event;
END;
$$;

-- Grant execute permission to supabase_auth_admin
GRANT EXECUTE ON FUNCTION public.custom_access_token_hook TO supabase_auth_admin;

-- Revoke execute permission from authenticated and anon roles for security
REVOKE EXECUTE ON FUNCTION public.custom_access_token_hook FROM authenticated, anon, public;

-- Verify the function was created successfully
SELECT 
  routine_name, 
  routine_type,
  security_type
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name = 'custom_access_token_hook';
