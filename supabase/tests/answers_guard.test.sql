-- Answer guard, including a later attempt after review. Service role until RLS policies exist.

begin;
select plan(7);

create temp table fx (
  teacher_id       uuid,
  student_id       uuid,
  company_id       uuid,
  homework_id      uuid,
  other_homework_id uuid,
  exercise1_id     uuid,
  exercise2_id     uuid,
  other_exercise_id uuid,
  assignment_id    uuid,
  answer1_id       uuid,
  answer2_id       uuid
);
grant all on table fx to service_role;

insert into fx (
  teacher_id, student_id, company_id, homework_id, other_homework_id,
  exercise1_id, exercise2_id, other_exercise_id, assignment_id, answer1_id, answer2_id
) values (
  tests.create_user('teacher-answers@pgtap.panthera.local', 'Teacher'),
  tests.create_user('student-answers@pgtap.panthera.local', 'Student'),
  gen_random_uuid(),
  gen_random_uuid(),
  gen_random_uuid(),
  gen_random_uuid(),
  gen_random_uuid(),
  gen_random_uuid(),
  gen_random_uuid(),
  gen_random_uuid(),
  gen_random_uuid()
);

select tests.use_service_role((select teacher_id from fx));

insert into public.companies (id, name, is_personal, created_by)
select company_id, 'Answers Center', false, teacher_id from fx;

insert into public.memberships (company_id, user_id, role, can_teach)
select company_id, teacher_id, 'teacher'::public.member_role, true from fx
union all
select company_id, student_id, 'student'::public.member_role, false from fx;

insert into public.homeworks (id, company_id, author_id, title, due_at)
select homework_id, company_id, teacher_id, 'Answers homework', timestamptz '2026-12-01 12:00:00+00'
from fx
union all
select other_homework_id, company_id, teacher_id, 'Other homework', timestamptz '2026-12-01 12:00:00+00'
from fx;

insert into public.homework_exercises (id, homework_id, company_id, description)
select exercise1_id, homework_id, company_id, 'First exercise' from fx
union all
select exercise2_id, homework_id, company_id, 'Second exercise' from fx
union all
select other_exercise_id, other_homework_id, company_id, 'Other exercise' from fx;

insert into public.assignments (id, homework_id, company_id, student_id)
select assignment_id, homework_id, company_id, student_id from fx;

select throws_ok(
  $$ insert into public.answers (assignment_id, company_id, exercise_id, attempt_no, body)
     select assignment_id, company_id, other_exercise_id, 1::smallint, 'no'
       from fx $$,
  '23514',
  null,
  'an exercise from another homework is rejected'
);

select throws_ok(
  $$ insert into public.answers (assignment_id, company_id, exercise_id, attempt_no, body)
     select assignment_id, company_id, exercise1_id, 2::smallint, 'too soon'
       from fx $$,
  '42501',
  null,
  'only the current attempt can be edited'
);

insert into public.answers (id, assignment_id, company_id, exercise_id, attempt_no, body)
select answer1_id, assignment_id, company_id, exercise1_id, 1::smallint, 'one' from fx
union all
select answer2_id, assignment_id, company_id, exercise2_id, 1::smallint, 'two' from fx;

select is(
  (select status::text from public.assignments where id = (select assignment_id from fx)),
  'in_progress',
  'the first saved answer starts the assignment'
);

update public.assignments set status = 'submitted' where id = (select assignment_id from fx);

select throws_ok(
  $$ update public.answers set body = 'late'
      where id = (select answer1_id from fx) $$,
  '42501',
  null,
  'answers are locked after submit'
);

insert into public.answer_reviews (answer_id, company_id, verdict)
select answer1_id, company_id, 'correct'::public.review_verdict from fx
union all
select answer2_id, company_id, 'incorrect'::public.review_verdict from fx;

update public.assignments set status = 'returned' where id = (select assignment_id from fx);

select is(
  (select current_attempt from public.assignments
    where id = (select assignment_id from fx)),
  2::smallint,
  'a return makes attempt 2 the current attempt'
);

select throws_ok(
  $$ insert into public.answers (assignment_id, company_id, exercise_id, attempt_no, body)
     select assignment_id, company_id, exercise1_id, 2::smallint, 'again'
       from fx $$,
  '42501',
  'this exercise was already marked correct',
  'an exercise marked correct cannot be answered again'
);

insert into public.answers (assignment_id, company_id, exercise_id, attempt_no, body)
select assignment_id, company_id, exercise2_id, 2::smallint, 'retry' from fx;

select is(
  (select status::text from public.assignments where id = (select assignment_id from fx)),
  'in_progress',
  'a new attempt can answer an exercise that was not correct'
);

select * from finish();
rollback;
