-- PB-17. Helpers and policies for profiles, companies, memberships, and event_types.
-- Other public tables stay row-level secure and have no policy, so the API sees nothing.
--
-- Access matrix. anon has no policy. A member of another company is denied.
--
-- profiles
--   select: own row, a roster link in either direction, or a shared event
--           (a cancelled event still counts). The visible row includes every column.
--   insert: no policy. handle_new_user writes the row.
--   update: own row, columns full_name and timezone only.
--   delete: no policy.
-- companies
--   select: a member, or the creator of a personal company (so the membership
--           insert in create_personal_workspace can see the new row).
--   insert: the caller, created_by is the caller, is_personal is true.
--           A user who already belongs to a company can create one personal company.
--   update: owner or admin, column name only.
--   delete: an owner of a personal company. A tutoring center has no delete path.
--           The delete removes members, lessons, and homework in that workspace.
-- memberships
--   select: own rows; owner and admin read every row in the company; a teacher
--           reads a student when teaches(company, student) is true.
--           Who else appears in the member list is decided later (PB-103).
--   insert: the caller, role owner, can_teach true, on a personal company
--           whose created_by is the caller. redeem_invite writes other rows
--           as a security definer function.
--   update: no policy. Role changes wait for a later phase.
--   delete: no policy. Leave-company waits for a later phase.
-- event_types
--   select: a member of that company.
--   insert: an owner, admin, or teacher, and created_by is the caller.
--           The deferred Lesson seed uses this path.
--   update: no policy.
--   delete: no policy.
--
-- On delete: an owner delete of a personal company uses the existing company
-- cascades. The membership trigger still deletes a personal company when the
-- owner membership goes first (account deletion). A guard skips that trigger
-- when the company delete is already running.

-- =============================================================================
-- 1. RLS helpers. Criteria: docs/security-definer-registry.md
-- =============================================================================

create function private.is_member(p_company_id uuid, p_roles public.member_role[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.memberships m
    where m.company_id = p_company_id
      and m.user_id = (select auth.uid())
      and m.role = any (p_roles)
  );
$$;

create function private.can_teach(p_company_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.memberships m
    where m.company_id = p_company_id
      and m.user_id = (select auth.uid())
      and m.can_teach
  );
$$;

create function private.teaches(p_company_id uuid, p_student_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.teacher_students ts
    where ts.company_id = p_company_id
      and ts.teacher_id = (select auth.uid())
      and ts.student_id = p_student_id
  );
$$;

-- True when both users are participants of the same event, including a cancelled event.
create function private.shares_event_with(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.event_participants mine
    join public.event_participants theirs
      on theirs.event_id = mine.event_id
     and theirs.user_id = p_user_id
    where mine.user_id = (select auth.uid())
  );
$$;

-- True when a teacher_students row links the caller and that user, in either direction.
create function private.shares_roster_with(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.teacher_students ts
    where (
      ts.teacher_id = (select auth.uid())
      and ts.student_id = p_user_id
    ) or (
      ts.student_id = (select auth.uid())
      and ts.teacher_id = p_user_id
    )
  );
$$;

revoke execute on function
  private.is_member(uuid, public.member_role[]),
  private.can_teach(uuid),
  private.teaches(uuid, uuid),
  private.shares_event_with(uuid),
  private.shares_roster_with(uuid)
from public, anon;

grant execute on function
  private.is_member(uuid, public.member_role[]),
  private.can_teach(uuid),
  private.teaches(uuid, uuid),
  private.shares_event_with(uuid),
  private.shares_roster_with(uuid)
to authenticated;

-- Helper predicates filter on these columns.
create index teacher_students_pair_idx
  on public.teacher_students (teacher_id, student_id);
create index teacher_students_student_pair_idx
  on public.teacher_students (student_id, teacher_id);
create index event_participants_user_event_idx
  on public.event_participants (user_id, event_id);

-- =============================================================================
-- 2. Personal-company delete guard
-- =============================================================================
-- Direct delete of the company cascades to memberships, and the membership
-- trigger would delete the company again. The guard records the company id
-- for this transaction. Account deletion still deletes the membership first,
-- so the trigger still removes the personal company on that path.

create function private.trg_companies_mark_deleting()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  perform set_config('panthera.deleting_company', old.id::text, true);
  return old;
end $$;

create trigger companies_mark_deleting
  before delete on public.companies
  for each row execute function private.trg_companies_mark_deleting();

revoke execute on function private.trg_companies_mark_deleting() from public, anon;

create or replace function private.trg_memberships_delete_personal_company()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.role = 'owner'
     and current_setting('panthera.deleting_company', true)
         is distinct from old.company_id::text
  then
    delete from public.companies c
     where c.id = old.company_id
       and c.is_personal;
  end if;
  return null;
end $$;

-- =============================================================================
-- 3. Policies
-- =============================================================================

create policy "profiles: self or related read"
  on public.profiles for select to authenticated
  using (
    id = (select auth.uid())
    or private.shares_roster_with(id)
    or private.shares_event_with(id)
  );

create policy "profiles: self updates name and timezone"
  on public.profiles for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

revoke update on table public.profiles from anon, authenticated;
grant update (full_name, timezone) on table public.profiles to authenticated;

create policy "companies: members and creator read"
  on public.companies for select to authenticated
  using (
    private.is_member(id, array['owner', 'admin', 'teacher', 'student']::public.member_role[])
    or (is_personal and created_by = (select auth.uid()))
  );

create policy "companies: personal insert"
  on public.companies for insert to authenticated
  with check (
    is_personal
    and created_by = (select auth.uid())
  );

create policy "companies: owner or admin renames"
  on public.companies for update to authenticated
  using (private.is_member(id, array['owner', 'admin']::public.member_role[]))
  with check (private.is_member(id, array['owner', 'admin']::public.member_role[]));

revoke update on table public.companies from anon, authenticated;
grant update (name) on table public.companies to authenticated;

create policy "companies: owner deletes personal"
  on public.companies for delete to authenticated
  using (
    is_personal
    and private.is_member(id, array['owner']::public.member_role[])
  );

create policy "memberships: self, staff, or teacher reads"
  on public.memberships for select to authenticated
  using (
    user_id = (select auth.uid())
    or private.is_member(company_id, array['owner', 'admin']::public.member_role[])
    or private.teaches(company_id, user_id)
  );

create policy "memberships: personal owner insert"
  on public.memberships for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and role = 'owner'
    and can_teach
    and exists (
      select 1
      from public.companies c
      where c.id = company_id
        and c.is_personal
        and c.created_by = (select auth.uid())
    )
  );

create policy "event_types: members read"
  on public.event_types for select to authenticated
  using (
    private.is_member(company_id, array['owner', 'admin', 'teacher', 'student']::public.member_role[])
  );

create policy "event_types: staff insert"
  on public.event_types for insert to authenticated
  with check (
    created_by = (select auth.uid())
    and private.is_member(company_id, array['owner', 'admin', 'teacher']::public.member_role[])
  );
