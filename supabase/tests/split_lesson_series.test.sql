-- split_lesson_series. Service role until RLS policies exist.
-- The company seed trigger is deferred until commit, so the test inserts the event type.

begin;
select plan(6);

create temp table fx (
  teacher_id    uuid,
  student_id    uuid,
  company_id    uuid,
  event_type_id uuid,
  old_id        uuid,
  new_id        uuid,
  blocked_id    uuid,
  participants  jsonb
);
grant all on table fx to service_role;

insert into fx (teacher_id, student_id, company_id, event_type_id)
values (
  tests.create_user('teacher-series@pgtap.panthera.local', 'Teacher'),
  tests.create_user('student-series@pgtap.panthera.local', 'Student'),
  gen_random_uuid(),
  gen_random_uuid()
);

select tests.use_service_role((select teacher_id from fx));

update fx
   set participants = jsonb_build_array(
     jsonb_build_object('user_id', teacher_id, 'role', 'teacher'),
     jsonb_build_object('user_id', student_id, 'role', 'student')
   );

insert into public.companies (id, name, is_personal, created_by)
select company_id, 'Series Center', false, teacher_id from fx;

insert into public.memberships (company_id, user_id, role, can_teach)
select company_id, teacher_id, 'teacher'::public.member_role, true from fx
union all
select company_id, student_id, 'student'::public.member_role, false from fx;

insert into public.event_types (id, company_id, name, is_default, created_by)
select event_type_id, company_id, 'Lesson', true, teacher_id from fx;

update fx
   set old_id = public.create_lesson_series(
     company_id,
     event_type_id,
     'FREQ=WEEKLY;COUNT=3',
     'Europe/Warsaw',
     interval '1 hour',
     array[
       timestamptz '2026-11-02 10:00:00+00',
       timestamptz '2026-11-09 10:00:00+00',
       timestamptz '2026-11-16 10:00:00+00'
     ],
     participants
   );

select throws_ok(
  $$ select public.split_lesson_series(
       (select old_id from fx),
       timestamptz '2026-11-02 10:00:00+00',
       'FREQ=WEEKLY;COUNT=1',
       'FREQ=WEEKLY;COUNT=2',
       'Europe/Warsaw',
       interval '1 hour',
       array[timestamptz '2026-11-02 10:00:00+00'],
       (select participants from fx)
     ) $$,
  '22023',
  null,
  'the split point must be after the first occurrence'
);

update fx
   set new_id = public.split_lesson_series(
     old_id,
     timestamptz '2026-11-09 10:00:00+00',
     'FREQ=WEEKLY;COUNT=1',
     'FREQ=WEEKLY;COUNT=2',
     'Europe/Warsaw',
     interval '1 hour',
     array[
       timestamptz '2026-11-09 10:00:00+00',
       timestamptz '2026-11-16 10:00:00+00'
     ],
     participants
   );

select is(
  (select count(*)::int from public.events where series_id = (select old_id from fx)),
  1,
  'the split keeps occurrences before the split point'
);

select is(
  (select count(*)::int from public.events where series_id = (select new_id from fx)),
  2,
  'the new series has the occurrences from the split point on'
);

select is(
  (select split_from_series_id from public.lesson_series where id = (select new_id from fx)),
  (select old_id from fx),
  'the new series records the series it was split from'
);

update fx
   set blocked_id = public.create_lesson_series(
     company_id,
     event_type_id,
     'FREQ=WEEKLY;COUNT=3',
     'Europe/Warsaw',
     interval '1 hour',
     array[
       timestamptz '2026-12-07 10:00:00+00',
       timestamptz '2026-12-14 10:00:00+00',
       timestamptz '2026-12-21 10:00:00+00'
     ],
     participants
   );

update public.event_participants ep
   set attendance = 'present'
  from public.events e
 where e.id = ep.event_id
   and e.series_id = (select blocked_id from fx)
   and e.original_starts_at >= timestamptz '2026-12-14 10:00:00+00'
   and ep.role = 'student';

select throws_ok(
  $$ select public.split_lesson_series(
       (select blocked_id from fx),
       timestamptz '2026-12-14 10:00:00+00',
       'FREQ=WEEKLY;COUNT=1',
       'FREQ=WEEKLY;COUNT=2',
       'Europe/Warsaw',
       interval '1 hour',
       array[timestamptz '2026-12-14 10:00:00+00'],
       (select participants from fx)
     ) $$,
  '23514',
  null,
  'a split stops when a future occurrence has attendance'
);

select throws_ok(
  $$ select public.split_lesson_series(
       '00000000-0000-4000-8000-000000000099',
       timestamptz '2026-11-09 10:00:00+00',
       'FREQ=WEEKLY;COUNT=1',
       'FREQ=WEEKLY;COUNT=1',
       'Europe/Warsaw',
       interval '1 hour',
       array[timestamptz '2026-11-09 10:00:00+00'],
       '[]'::jsonb
     ) $$,
  'P0002',
  null,
  'a missing series is not found'
);

select * from finish();
rollback;
