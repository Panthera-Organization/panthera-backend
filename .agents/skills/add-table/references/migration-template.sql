-- Access: teacher (own company) read/write; student reads homework assigned to them; others none.
-- On delete: company → cascade (tenant removed); created_by → set null (content survives teacher deletion).

create table public.homeworks (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete cascade,
  created_by uuid references public.profiles (id) on delete set null,
  title text not null,
  due_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Index every foreign key: RLS policies filter on them constantly.
create index homeworks_company_id_idx on public.homeworks (company_id);
create index homeworks_created_by_idx on public.homeworks (created_by);

-- Keep updated_at current. If public.set_updated_at() doesn't exist yet,
-- create it in its own earlier migration.
create trigger homeworks_set_updated_at
  before update on public.homeworks
  for each row execute function public.set_updated_at();

-- Enum example (mirrored as a GraphQL enum):
-- create type public.assignment_status as enum
--   ('assigned', 'in_progress', 'submitted', 'reviewed', 'returned');

-- File example: store the Storage path, never a URL.
-- image_path text
