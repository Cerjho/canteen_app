-- Adds needs_onboarding flag to users and code to students
-- Safe to run multiple times (IF NOT EXISTS checks)

-- users.needs_onboarding boolean default true
alter table if exists public.users
  add column if not exists needs_onboarding boolean not null default true;

-- students.code unique text for parent linking
alter table if exists public.students
  add column if not exists code text unique;

-- Optional: create an index to speed up lookups by code
create index if not exists idx_students_code on public.students (code);
