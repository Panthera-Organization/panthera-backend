-- Companies
create table public.companies (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  created_at  timestamptz default now()
);

-- Profiles (extends auth.users)
create table public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  company_id  uuid references public.companies(id) on delete cascade,
  role        text not null check (role in ('owner','admin','teacher','student')),
  full_name   text not null,
  avatar_url  text,
  created_at  timestamptz default now()
);

-- Teacher ↔ Student relationship
create table public.teacher_students (
  id          uuid primary key default gen_random_uuid(),
  teacher_id  uuid not null references public.profiles(id),
  student_id  uuid not null references public.profiles(id),
  company_id  uuid not null references public.companies(id),
  created_at  timestamptz default now(),
  unique (teacher_id, student_id)
);

-- -- Invite codes / links
-- create table public.invitations (
--   id          uuid primary key default gen_random_uuid(),
--   company_id  uuid not null references public.companies(id),
--   teacher_id  uuid not null references public.profiles(id),
--   code        text not null unique,
--   payload     jsonb default '{}',   -- course, group, etc.
--   used_by     uuid references public.profiles(id),
--   expires_at  timestamptz not null,
--   created_at  timestamptz default now()
-- );
