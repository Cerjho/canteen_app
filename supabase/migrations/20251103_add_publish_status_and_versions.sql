-- Migration: Add publish_status and versioning for weekly_menus
-- Date: 2025-11-03

-- 1) Create enum or use check constraint; here we use an enum-like check on text for portability
ALTER TABLE public.weekly_menus
  ADD COLUMN IF NOT EXISTS publish_status text NOT NULL DEFAULT 'draft' CHECK (publish_status IN ('draft','published','archived')),
  ADD COLUMN IF NOT EXISTS current_version integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS published_at timestamptz NULL,
  ADD COLUMN IF NOT EXISTS archived_at timestamptz NULL;

-- 2) Create versions table to store snapshots on publish
CREATE TABLE IF NOT EXISTS public.weekly_menu_versions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  weekly_menu_id uuid NOT NULL REFERENCES public.weekly_menus(id) ON DELETE CASCADE,
  version integer NOT NULL,
  week_start date NOT NULL,
  menu_items_by_day jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid NULL
);

-- 3) Uniqueness of versions per weekly menu
CREATE UNIQUE INDEX IF NOT EXISTS weekly_menu_versions_unique ON public.weekly_menu_versions(weekly_menu_id, version);

-- 4) Helpful indexes
CREATE INDEX IF NOT EXISTS weekly_menu_versions_week_start_idx ON public.weekly_menu_versions(week_start);
CREATE INDEX IF NOT EXISTS weekly_menus_publish_status_idx ON public.weekly_menus(publish_status);

-- 5) Backfill existing rows to draft status (already default), and set current_version
UPDATE public.weekly_menus
SET publish_status = COALESCE(publish_status, 'draft'),
    current_version = COALESCE(current_version, 0)
WHERE true;
