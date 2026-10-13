-- Profile reads and the name/timezone update.

begin;
select plan(17);

create temp table fx (
  owner_id    uuid,
  admin_id    uuid,
  teacher_id  uuid,
  student_a   uuid,
  student_b   uuid,
  student_d   uuid,
  stranger_id uuid,
  company_a   uuid,
  company_b   uuid,
  lesson_id   uuid,
  event_id    uuid
);
grant all on table fx to anon, authenticated;

insert into fx (
  owner_id, admin_id, teacher_id, student_a, student_b, student_d, stranger_id,
  company_a, company_b
) values (
  tests.create_user('profile-owner@pgtap.panthera.local', 'Owner'),
  tests.create_user('profile-admin@pgtap.panthera.local', 'Admin'),
  tests.create_user('profile-teacher@pgtap.panthera.local', 'Teacher'),
  tests.create_user('profile-student-a@pgtap.panthera.local', 'Student A'),
  tests.create_user('profile-student-b@pgtap.panthera.local', 'Student B'),
  tests.create_user('profile-student-d@pgtap.panthera.local', 'Student D'),
  tests.create_user('profile-stranger@pgtap.panthera.local', 'Stranger'),
  gen_random_uuid(),
  gen_random_uuid()
);

insert into public.companies (id, name, is_personal, created_by)
select company_a, 'Profile Center', false, owner_id from fx
union all
select company_b, 'Other Center', false, stranger_id from fx;

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
select company_a, student_d, 'student'::public.member_role, false from fx
union all
select company_b, stranger_id, 'owner'::public.member_role, true from fx;

insert into public.teacher_students (company_id, teacher_id, student_id, is_direct)
select company_a, teacher_id, student_a, true from fx;

update public.profiles
   set avatar_path = 'avatars/student-a.png',
       timezone = 'Europe/Warsaw'
 where id = (select student_a from fx);

set constraints all immediate;
set constraints all deferred;

update fx
   set lesson_id = (
     select id from public.event_types
      where company_id = fx.company_a and name = 'Lesson'
   ),
       event_id = gen_random_uuid();

insert into public.events (
  id, company_id, event_type_id, starts_at, ends_at, status, cancelled_at
)
select event_id, company_a, lesson_id, now(), now() + interval '1 hour',
       'cancelled', now()
  from fx;

insert into public.event_participants (event_id, company_id, user_id, role)
select event_id, company_a, student_a, 'student'::public.participant_role from fx
union all
select event_id, company_a, student_b, 'student'::public.participant_role from fx;

select tests.authenticate_as((select owner_id from fx));
select is(
  (select full_name from public.profiles where id = (select owner_id from fx)),
  'Owner',
  'an owner reads their own profile'
);
reset role;

select tests.authenticate_as((select admin_id from fx));
select is(
  (select full_name from public.profiles where id = (select admin_id from fx)),
  'Admin',
  'an admin reads their own profile'
);
reset role;

select tests.authenticate_as((select teacher_id from fx));
select results_eq(
  $$ select full_name, timezone, avatar_path
       from public.profiles
      where id = (select student_a from fx) $$,
  $$ values ('Student A', 'Europe/Warsaw', 'avatars/student-a.png') $$,
  'a teacher reads the linked student profile'
);
reset role;

select tests.authenticate_as((select student_a from fx));
select is(
  (select full_name from public.profiles where id = (select teacher_id from fx)),
  'Teacher',
  'a student reads the linked teacher profile'
);

select is(
  (select full_name from public.profiles where id = (select student_b from fx)),
  'Student B',
  'students who share a cancelled event read each other'
);

select is_empty(
  $$ select 1 from public.profiles where id = (select student_d from fx) $$,
  'a student cannot read an unlinked student profile'
);

select is_empty(
  $$ select 1 from public.profiles where id = (select stranger_id from fx) $$,
  'a student cannot read another company profile'
);

select lives_ok(
  $$ update public.profiles
        set full_name = 'Ada', timezone = 'Europe/London'
      where id = (select student_a from fx) $$,
  'a user can save their name and timezone'
);

select is(
  (select full_name from public.profiles where id = (select student_a from fx)),
  'Ada',
  'the saved name is stored'
);

select throws_ok(
  $$ update public.profiles
        set avatar_path = 'avatars/new.png'
      where id = (select student_a from fx) $$,
  '42501',
  null,
  'a user cannot save an avatar path'
);

select lives_ok(
  $$ update public.profiles
        set full_name = 'Taken'
      where id = (select teacher_id from fx) $$,
  'an update of another profile does not raise'
);

select is(
  (select full_name from public.profiles where id = (select teacher_id from fx)),
  'Teacher',
  'a user cannot change another profile'
);

select throws_ok(
  $$ insert into public.profiles (id, full_name)
     values ('00000000-0000-0000-0000-000000000099', 'New') $$,
  '42501',
  null,
  'a user cannot insert a profile'
);

select lives_ok(
  $$ delete from public.profiles where id = (select student_a from fx) $$,
  'a profile delete does not raise'
);

select is(
  (select count(*)::int from public.profiles where id = (select student_a from fx)),
  1,
  'a user cannot delete their profile'
);
reset role;

select tests.authenticate_as((select stranger_id from fx));
select is_empty(
  $$ select 1 from public.profiles where id = (select student_a from fx) $$,
  'another company cannot read the profile'
);
reset role;

select tests.authenticate_as(null);
select is_empty(
  $$ select 1 from public.profiles $$,
  'anon reads no profiles'
);
reset role;

select * from finish();
rollback;
