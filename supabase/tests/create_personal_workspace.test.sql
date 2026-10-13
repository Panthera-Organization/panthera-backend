-- create_personal_workspace under RLS, including the deferred Lesson seed.
-- The seed trigger waits until constraint-check time. SET CONSTRAINTS ALL
-- IMMEDIATE runs that check and leaves the transaction open. ROLLBACK then
-- removes the company, the membership, and the Lesson row.

begin;
select plan(16);

create temp table fx (
  newcomer_id uuid,
  student_id  uuid,
  center_id   uuid
);
grant all on table fx to anon, authenticated;

create temp table newcomer_workspace (company_id uuid);
grant all on table newcomer_workspace to anon, authenticated;

create temp table student_workspace (company_id uuid);
grant all on table student_workspace to anon, authenticated;

insert into fx (newcomer_id, student_id, center_id)
values (
  tests.create_user('workspace-newcomer@pgtap.panthera.local', 'Newcomer'),
  tests.create_user('workspace-student@pgtap.panthera.local', 'Student'),
  gen_random_uuid()
);

insert into public.companies (id, name, is_personal, created_by)
select center_id, 'Center', false, student_id from fx;

insert into public.memberships (company_id, user_id, role, can_teach)
select center_id, student_id, 'student'::public.member_role, false from fx;

-- Seed the center Lesson row as the table owner, before the caller switches role.
set constraints all immediate;
set constraints all deferred;

select tests.authenticate_as((select newcomer_id from fx));

select lives_ok(
  $$ insert into newcomer_workspace
     select public.create_personal_workspace('Ada space') $$,
  'a user with no company can create one personal workspace'
);

select is(
  (select name from public.companies
    where id = (select company_id from newcomer_workspace)),
  'Ada space',
  'the workspace keeps the passed name'
);

select is(
  (select is_personal from public.companies
    where id = (select company_id from newcomer_workspace)),
  true,
  'the new company is personal'
);

select is(
  (select created_by from public.companies
    where id = (select company_id from newcomer_workspace)),
  (select newcomer_id from fx),
  'the caller is created_by'
);

select is(
  (select role::text from public.memberships
    where company_id = (select company_id from newcomer_workspace)
      and user_id = (select newcomer_id from fx)),
  'owner',
  'the caller becomes the owner'
);

select is(
  (select can_teach from public.memberships
    where company_id = (select company_id from newcomer_workspace)
      and user_id = (select newcomer_id from fx)),
  true,
  'the new owner can teach'
);

select is(
  (select count(*)::int from public.memberships
    where user_id = (select newcomer_id from fx)),
  1,
  'the caller has only this membership'
);

set constraints all immediate;

select is(
  (select name from public.event_types
    where company_id = (select company_id from newcomer_workspace)),
  'Lesson',
  'the Lesson event type exists when the deferred seed runs'
);

select throws_ok(
  $$ select public.create_personal_workspace('Again') $$,
  '23505',
  null,
  'a second personal company is refused'
);

reset role;
set constraints all deferred;

select tests.authenticate_as((select student_id from fx));

select lives_ok(
  $$ insert into student_workspace
     select public.create_personal_workspace('Student space') $$,
  'a student who already belongs to a company can create a personal workspace'
);

select is(
  (select name from public.companies
    where id = (select company_id from student_workspace)),
  'Student space',
  'the student workspace keeps the passed name'
);

select is(
  (select is_personal from public.companies
    where id = (select company_id from student_workspace)),
  true,
  'the student company is personal'
);

select is(
  (select created_by from public.companies
    where id = (select company_id from student_workspace)),
  (select student_id from fx),
  'the student is created_by'
);

select results_eq(
  $$ select role::text
       from public.memberships
      where user_id = (select student_id from fx)
      order by 1 $$,
  array['owner', 'student'],
  'the student keeps the center membership and owns the workspace'
);

select is(
  (select can_teach from public.memberships
    where company_id = (select company_id from student_workspace)
      and user_id = (select student_id from fx)),
  true,
  'the student workspace owner can teach'
);

set constraints all immediate;

select is(
  (select name from public.event_types
    where company_id = (select company_id from student_workspace)),
  'Lesson',
  'the Lesson event type exists for the student workspace'
);

reset role;

select * from finish();
rollback;
