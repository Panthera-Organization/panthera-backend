-- tests.create_user and tests.authenticate_as.
-- Owner, admin, teacher, and student are membership roles. Anon has no user.

begin;
select plan(8);

create temp table fx (
  owner_id   uuid,
  admin_id   uuid,
  teacher_id uuid,
  student_id uuid,
  company_id uuid
);

insert into fx (owner_id, admin_id, teacher_id, student_id, company_id)
values (
  tests.create_user('owner@pgtap.panthera.local', 'Owner'),
  tests.create_user('admin@pgtap.panthera.local', 'Admin'),
  tests.create_user('teacher@pgtap.panthera.local', 'Teacher'),
  tests.create_user('student@pgtap.panthera.local', 'Student'),
  gen_random_uuid()
);

insert into public.companies (id, name, is_personal, created_by)
select company_id, 'Harness Center', false, owner_id from fx;

insert into public.memberships (company_id, user_id, role, can_teach)
select company_id, owner_id, 'owner'::public.member_role, false from fx
union all
select company_id, admin_id, 'admin'::public.member_role, false from fx
union all
select company_id, teacher_id, 'teacher'::public.member_role, true from fx
union all
select company_id, student_id, 'student'::public.member_role, false from fx;

create temp table session_seen (
  label   text primary key,
  uid     uuid,
  db_role text
);
grant all on table session_seen to anon, authenticated, service_role;

select tests.authenticate_as((select owner_id from fx));
insert into session_seen values ('owner', auth.uid(), current_user::text);
reset role;

select tests.authenticate_as((select admin_id from fx));
insert into session_seen values ('admin', auth.uid(), current_user::text);
reset role;

select tests.authenticate_as((select teacher_id from fx));
insert into session_seen values ('teacher', auth.uid(), current_user::text);
reset role;

select tests.authenticate_as((select student_id from fx));
insert into session_seen values ('student', auth.uid(), current_user::text);
reset role;

select tests.authenticate_as(null);
insert into session_seen values ('anon', auth.uid(), current_user::text);
reset role;

select tests.use_service_role((select owner_id from fx));
insert into session_seen values ('service', auth.uid(), current_user::text);
reset role;

select is(
  (select full_name from public.profiles where id = (select owner_id from fx)),
  'Owner',
  'create_user stores the profile name'
);

select results_eq(
  $$ select m.role::text
       from public.memberships m
       join fx on fx.company_id = m.company_id
      order by 1 $$,
  array['admin', 'owner', 'student', 'teacher'],
  'the company has an owner, an admin, a teacher, and a student'
);

select is(
  (select uid::text || ':' || db_role from session_seen where label = 'owner'),
  (select owner_id::text from fx) || ':authenticated',
  'authenticate_as acts as the owner'
);

select is(
  (select uid::text || ':' || db_role from session_seen where label = 'admin'),
  (select admin_id::text from fx) || ':authenticated',
  'authenticate_as acts as the admin'
);

select is(
  (select uid::text || ':' || db_role from session_seen where label = 'teacher'),
  (select teacher_id::text from fx) || ':authenticated',
  'authenticate_as acts as the teacher'
);

select is(
  (select uid::text || ':' || db_role from session_seen where label = 'student'),
  (select student_id::text from fx) || ':authenticated',
  'authenticate_as acts as the student'
);

select is(
  (select coalesce(uid::text, '') || ':' || db_role from session_seen where label = 'anon'),
  ':anon',
  'authenticate_as(null) acts as anon'
);

select is(
  (select uid::text || ':' || db_role from session_seen where label = 'service'),
  (select owner_id::text from fx) || ':service_role',
  'use_service_role keeps the caller and bypasses RLS'
);

select * from finish();
rollback;
