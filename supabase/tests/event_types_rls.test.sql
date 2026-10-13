-- Event type read and insert.

begin;
select plan(12);

create temp table fx (
  owner_id   uuid,
  teacher_id uuid,
  student_id uuid,
  other_id   uuid,
  company_a  uuid,
  company_b  uuid
);
grant all on table fx to anon, authenticated;

insert into fx (owner_id, teacher_id, student_id, other_id, company_a, company_b)
values (
  tests.create_user('type-owner@pgtap.panthera.local', 'Owner'),
  tests.create_user('type-teacher@pgtap.panthera.local', 'Teacher'),
  tests.create_user('type-student@pgtap.panthera.local', 'Student'),
  tests.create_user('type-other@pgtap.panthera.local', 'Other'),
  gen_random_uuid(),
  gen_random_uuid()
);

insert into public.companies (id, name, is_personal, created_by)
select company_a, 'Type Center', false, owner_id from fx
union all
select company_b, 'Other Center', false, other_id from fx;

insert into public.memberships (company_id, user_id, role, can_teach)
select company_a, owner_id, 'owner'::public.member_role, false from fx
union all
select company_a, teacher_id, 'teacher'::public.member_role, true from fx
union all
select company_a, student_id, 'student'::public.member_role, false from fx
union all
select company_b, other_id, 'teacher'::public.member_role, true from fx;

set constraints all immediate;
set constraints all deferred;

select tests.authenticate_as((select student_id from fx));
select is(
  (select name from public.event_types
    where company_id = (select company_a from fx) and is_default),
  'Lesson',
  'a member reads Lesson'
);

select lives_ok(
  $$ update public.event_types set name = 'Class'
      where company_id = (select company_a from fx) and is_default $$,
  'an event type update does not raise'
);

select is(
  (select name from public.event_types
    where company_id = (select company_a from fx) and is_default),
  'Lesson',
  'a member cannot rename Lesson'
);

select lives_ok(
  $$ delete from public.event_types
      where company_id = (select company_a from fx) and is_default $$,
  'an event type delete does not raise'
);

select is(
  (select count(*)::int from public.event_types
    where company_id = (select company_a from fx) and name = 'Lesson'),
  1,
  'a member cannot delete Lesson'
);

select throws_ok(
  $$ insert into public.event_types (company_id, name, created_by)
     select company_a, 'Exam', student_id from fx $$,
  '42501',
  null,
  'a student cannot add an event type'
);
reset role;

select tests.authenticate_as((select teacher_id from fx));
select lives_ok(
  $$ insert into public.event_types (company_id, name, created_by)
     select company_a, 'Exam', teacher_id from fx $$,
  'a teacher can add an event type'
);

select throws_ok(
  $$ insert into public.event_types (company_id, name, created_by)
     select company_a, 'Wrong Author', owner_id from fx $$,
  '42501',
  null,
  'created_by must be the caller'
);
reset role;

select tests.authenticate_as((select owner_id from fx));
select lives_ok(
  $$ insert into public.event_types (company_id, name, created_by)
     select company_a, 'Meeting', owner_id from fx $$,
  'an owner with can_teach false can add an event type'
);
reset role;

select tests.authenticate_as((select other_id from fx));
select is_empty(
  $$ select 1 from public.event_types where company_id = (select company_a from fx) $$,
  'another company cannot read these event types'
);

select throws_ok(
  $$ insert into public.event_types (company_id, name, created_by)
     select company_a, 'Foreign', other_id from fx $$,
  '42501',
  null,
  'a teacher cannot add an event type in another company'
);
reset role;

select tests.authenticate_as(null);
select is_empty(
  $$ select 1 from public.event_types $$,
  'anon reads no event types'
);
reset role;

select * from finish();
rollback;
