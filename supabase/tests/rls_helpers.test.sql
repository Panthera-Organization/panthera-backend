-- RLS helpers and the policies that call them.

begin;
select plan(11);

create temp table fx (
  owner_id   uuid,
  teacher_id uuid,
  company_id uuid
);
grant all on table fx to anon, authenticated;

insert into fx (owner_id, teacher_id, company_id)
values (
  tests.create_user('helper-owner@pgtap.panthera.local', 'Owner'),
  tests.create_user('helper-teacher@pgtap.panthera.local', 'Teacher'),
  gen_random_uuid()
);

insert into public.companies (id, name, is_personal, created_by)
select company_id, 'Helper Center', false, owner_id from fx;

insert into public.memberships (company_id, user_id, role, can_teach)
select company_id, owner_id, 'owner'::public.member_role, false from fx
union all
select company_id, teacher_id, 'teacher'::public.member_role, true from fx;

select is(
  (select count(*)::int
     from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'r'
      and c.relname in ('profiles', 'companies', 'memberships', 'event_types')
      and c.relrowsecurity),
  4,
  'RLS is enabled on profiles, companies, memberships, and event_types'
);

select is(
  (select count(*)::int
     from pg_policies
    where schemaname = 'public'
      and tablename not in ('profiles', 'companies', 'memberships', 'event_types')),
  0,
  'other public tables have no policies'
);

select ok(
  (select qual like '%shares_roster_with%'
     from pg_policies
    where schemaname = 'public'
      and policyname = 'profiles: self or related read'),
  'profiles select calls shares_roster_with'
);

select ok(
  (select qual like '%shares_event_with%'
     from pg_policies
    where schemaname = 'public'
      and policyname = 'profiles: self or related read'),
  'profiles select calls shares_event_with'
);

select ok(
  (select qual like '%is_member%'
     from pg_policies
    where schemaname = 'public'
      and policyname = 'memberships: self, owner, admin, or teacher reads'),
  'memberships select calls is_member'
);

select ok(
  (select qual like '%teaches%'
     from pg_policies
    where schemaname = 'public'
      and policyname = 'memberships: self, owner, admin, or teacher reads'),
  'memberships select calls teaches'
);

select ok(
  (select qual like '%is_member%'
     from pg_policies
    where schemaname = 'public'
      and policyname = 'companies: owner deletes personal'),
  'company delete calls is_member'
);

select ok(
  (select with_check like '%is_member%'
     from pg_policies
    where schemaname = 'public'
      and policyname = 'event_types: owner, admin, or teacher insert'),
  'event type insert calls is_member'
);

select tests.authenticate_as((select teacher_id from fx));
select is(
  private.can_teach((select company_id from fx)),
  true,
  'can_teach is true for a teacher'
);
reset role;

select tests.authenticate_as((select owner_id from fx));
select is(
  private.can_teach((select company_id from fx)),
  false,
  'can_teach is false for an owner when the flag is false'
);
reset role;

select tests.authenticate_as(null);
select throws_ok(
  $$ select private.is_member(
       (select company_id from fx),
       array['owner']::public.member_role[]
     ) $$,
  '42501',
  null,
  'anon cannot execute an RLS helper'
);
reset role;

select * from finish();
rollback;
