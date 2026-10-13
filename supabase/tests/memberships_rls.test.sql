-- Membership reads, and the closed update and delete paths.

begin;
select plan(13);

create temp table fx (
  owner_id   uuid,
  admin_id   uuid,
  teacher_id uuid,
  student_a  uuid,
  student_b  uuid,
  other_id   uuid,
  company_a  uuid,
  company_b  uuid
);
grant all on table fx to anon, authenticated;

insert into fx (
  owner_id, admin_id, teacher_id, student_a, student_b, other_id, company_a, company_b
) values (
  tests.create_user('member-owner@pgtap.panthera.local', 'Owner'),
  tests.create_user('member-admin@pgtap.panthera.local', 'Admin'),
  tests.create_user('member-teacher@pgtap.panthera.local', 'Teacher'),
  tests.create_user('member-student-a@pgtap.panthera.local', 'Student A'),
  tests.create_user('member-student-b@pgtap.panthera.local', 'Student B'),
  tests.create_user('member-other@pgtap.panthera.local', 'Other'),
  gen_random_uuid(),
  gen_random_uuid()
);

insert into public.companies (id, name, is_personal, created_by)
select company_a, 'Member Center', false, owner_id from fx
union all
select company_b, 'Other Center', false, other_id from fx;

insert into public.memberships (company_id, user_id, role, can_teach)
select company_a, owner_id, 'owner'::public.member_role, false from fx
union all
select company_a, admin_id, 'admin'::public.member_role, false from fx
union all
select company_a, teacher_id, 'teacher'::public.member_role, true from fx
union all
select company_a, student_a, 'student'::public.member_role, false from fx
union all
select company_a, student_b, 'student'::public.member_role, false from fx
union all
select company_b, other_id, 'teacher'::public.member_role, true from fx;

insert into public.teacher_students (company_id, teacher_id, student_id, is_direct)
select company_a, teacher_id, student_a, true from fx;

select tests.authenticate_as((select student_a from fx));
select results_eq(
  $$ select user_id::text
       from public.memberships
      where company_id = (select company_a from fx)
      order by 1 $$,
  $$ select student_a::text from fx $$,
  'student A cannot read student B membership'
);

select lives_ok(
  $$ update public.memberships set role = 'teacher'
      where company_id = (select company_a from fx)
        and user_id = (select student_a from fx) $$,
  'a role update does not raise'
);

select is(
  (select role::text from public.memberships
    where company_id = (select company_a from fx)
      and user_id = (select student_a from fx)),
  'student',
  'a member cannot change their own role'
);

select lives_ok(
  $$ delete from public.memberships
      where company_id = (select company_a from fx)
        and user_id = (select student_a from fx) $$,
  'a membership delete does not raise'
);

select is(
  (select count(*)::int from public.memberships
    where company_id = (select company_a from fx)
      and user_id = (select student_a from fx)),
  1,
  'a member cannot delete a membership'
);

select throws_ok(
  $$ insert into public.memberships (company_id, user_id, role, can_teach)
     select company_b, student_a, 'owner'::public.member_role, true from fx $$,
  '42501',
  null,
  'a student cannot insert a membership'
);
reset role;

select tests.authenticate_as((select teacher_id from fx));
select results_eq(
  $$ select user_id::text
       from public.memberships
      where company_id = (select company_a from fx)
      order by 1 $$,
  $$ select id::text from (
       select student_a as id from fx
       union all
       select teacher_id from fx
     ) people
     order by 1 $$,
  'a teacher reads their own row and their student'
);
reset role;

select tests.authenticate_as((select owner_id from fx));
select results_eq(
  $$ select user_id::text
       from public.memberships
      where company_id = (select company_a from fx)
      order by 1 $$,
  $$ select id::text from (
       select owner_id as id from fx
       union all select admin_id from fx
       union all select teacher_id from fx
       union all select student_a from fx
       union all select student_b from fx
     ) people
     order by 1 $$,
  'an owner reads every member of the company'
);

select lives_ok(
  $$ update public.memberships set role = 'teacher'
      where company_id = (select company_a from fx)
        and user_id = (select student_b from fx) $$,
  'an owner role update does not raise'
);

select is(
  (select role::text from public.memberships
    where company_id = (select company_a from fx)
      and user_id = (select student_b from fx)),
  'student',
  'an owner cannot change a member role yet'
);
reset role;

select tests.authenticate_as((select admin_id from fx));
select is(
  (select count(*)::int from public.memberships
    where company_id = (select company_a from fx)),
  5,
  'an admin reads every member of the company'
);
reset role;

select tests.authenticate_as((select other_id from fx));
select is_empty(
  $$ select 1 from public.memberships where company_id = (select company_a from fx) $$,
  'a teacher cannot read another company'
);
reset role;

select tests.authenticate_as(null);
select is_empty(
  $$ select 1 from public.memberships $$,
  'anon reads no memberships'
);
reset role;

select * from finish();
rollback;
