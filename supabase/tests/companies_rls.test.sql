-- Company read, personal-workspace create, rename, and personal delete.

begin;
select plan(24);

create temp table fx (
  owner_id  uuid,
  admin_id  uuid,
  teacher_id uuid,
  student_id uuid,
  other_id  uuid,
  center_a  uuid,
  center_b  uuid
);
grant all on table fx to anon, authenticated;

create temp table created_workspace (company_id uuid);
grant all on table created_workspace to anon, authenticated;

insert into fx (owner_id, admin_id, teacher_id, student_id, other_id, center_a, center_b)
values (
  tests.create_user('company-owner@pgtap.panthera.local', 'Owner'),
  tests.create_user('company-admin@pgtap.panthera.local', 'Admin'),
  tests.create_user('company-teacher@pgtap.panthera.local', 'Teacher'),
  tests.create_user('company-student@pgtap.panthera.local', 'Student'),
  tests.create_user('company-other@pgtap.panthera.local', 'Other'),
  gen_random_uuid(),
  gen_random_uuid()
);

insert into public.companies (id, name, is_personal, created_by)
select center_a, 'Center A', false, owner_id from fx
union all
select center_b, 'Center B', false, other_id from fx;

insert into public.memberships (company_id, user_id, role, can_teach)
select center_a, owner_id, 'owner'::public.member_role, false from fx
union all
select center_a, admin_id, 'admin'::public.member_role, false from fx
union all
select center_a, teacher_id, 'teacher'::public.member_role, true from fx
union all
select center_a, student_id, 'student'::public.member_role, false from fx
union all
select center_b, other_id, 'owner'::public.member_role, true from fx;

set constraints all immediate;
set constraints all deferred;

select tests.authenticate_as((select student_id from fx));
select is(
  (select name from public.companies where id = (select center_a from fx)),
  'Center A',
  'a member reads their company'
);

select is_empty(
  $$ select 1 from public.companies where id = (select center_b from fx) $$,
  'a member cannot read another company'
);

select lives_ok(
  $$ insert into created_workspace
     select public.create_personal_workspace('Student space') $$,
  'a student who already belongs to a company can create a personal workspace'
);

set constraints all immediate;

select is(
  (select name from public.event_types
    where company_id = (select company_id from created_workspace)),
  'Lesson',
  'the Lesson event type exists for the new workspace'
);

select is(
  (select name from public.companies
    where id = (select company_id from created_workspace)),
  'Student space',
  'the creator reads the new personal company'
);

select throws_ok(
  $$ select public.create_personal_workspace('Again') $$,
  '23505',
  null,
  'a second personal company is refused'
);
reset role;

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
    where user_id = (select student_id from fx) and role = 'owner'),
  true,
  'the new workspace owner can teach'
);

select tests.authenticate_as((select other_id from fx));
select is_empty(
  $$ select 1 from public.companies where id = (select center_a from fx) $$,
  'an owner cannot read another company'
);
reset role;

select tests.authenticate_as(null);
select is_empty($$ select 1 from public.companies $$, 'anon reads no companies');
reset role;

select tests.authenticate_as((select owner_id from fx));
select lives_ok(
  $$ update public.companies set name = 'Renamed Center'
      where id = (select center_a from fx) $$,
  'an owner can rename the company'
);

select is(
  (select name from public.companies where id = (select center_a from fx)),
  'Renamed Center',
  'the owner name change is stored'
);

select throws_ok(
  $$ update public.companies set is_personal = true
      where id = (select center_a from fx) $$,
  '42501',
  null,
  'an owner cannot change the personal flag'
);
reset role;

select tests.authenticate_as((select admin_id from fx));
select lives_ok(
  $$ update public.companies set name = 'Admin Center'
      where id = (select center_a from fx) $$,
  'an admin can rename the company'
);
reset role;

select tests.authenticate_as((select teacher_id from fx));
select lives_ok(
  $$ update public.companies set name = 'Teacher Center'
      where id = (select center_a from fx) $$,
  'a teacher rename does not raise'
);

select is(
  (select name from public.companies where id = (select center_a from fx)),
  'Admin Center',
  'a teacher cannot rename the company'
);

select throws_ok(
  $$ insert into public.companies (name, is_personal, created_by)
     values ('New Center', false, (select teacher_id from fx)) $$,
  '42501',
  null,
  'a user cannot create a tutoring center'
);

select throws_ok(
  $$ insert into public.companies (name, is_personal, created_by)
     values ('Not Mine', true, (select owner_id from fx)) $$,
  '42501',
  null,
  'a user cannot create a company for someone else'
);
reset role;

create temp table pupil (id uuid);
insert into pupil
select tests.create_user('company-pupil@pgtap.panthera.local', 'Pupil');

insert into public.memberships (company_id, user_id, role, can_teach)
select w.company_id, p.id, 'student'::public.member_role, false
  from created_workspace w
  cross join pupil p;

select tests.authenticate_as((select student_id from fx));
select lives_ok(
  $$ delete from public.companies
      where id = (select company_id from created_workspace) $$,
  'the owner can delete a personal company'
);
reset role;

select is(
  (select count(*)::int from public.companies
    where id = (select company_id from created_workspace)),
  0,
  'the personal company is gone'
);

select is(
  (select count(*)::int from public.memberships
    where user_id = (select id from pupil)),
  0,
  'a student of the deleted workspace is removed'
);

select is(
  (select count(*)::int from public.memberships
    where user_id = (select student_id from fx)
      and company_id = (select center_a from fx)),
  1,
  'the owner keeps the other company'
);

select tests.authenticate_as((select owner_id from fx));
select lives_ok(
  $$ delete from public.companies where id = (select center_a from fx) $$,
  'a center delete does not raise'
);
reset role;

select is(
  (select count(*)::int from public.companies where id = (select center_a from fx)),
  1,
  'an owner cannot delete a tutoring center'
);

select * from finish();
rollback;
