-- Assignment status machine. Service role until RLS policies exist.

begin;
select plan(10);

create temp table fx (
  teacher_id           uuid,
  student_id           uuid,
  student2_id          uuid,
  company_id           uuid,
  homework_id          uuid,
  review_homework_id   uuid,
  readonly_homework_id uuid,
  main_id              uuid,
  review_id            uuid,
  stay_id              uuid,
  readonly_id          uuid
);
grant all on table fx to service_role;

insert into fx (
  teacher_id, student_id, student2_id, company_id,
  homework_id, review_homework_id, readonly_homework_id,
  main_id, review_id, stay_id, readonly_id
) values (
  tests.create_user('teacher-status@pgtap.panthera.local', 'Teacher'),
  tests.create_user('student-status@pgtap.panthera.local', 'Student'),
  tests.create_user('student2-status@pgtap.panthera.local', 'Student Two'),
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
select company_id, 'Status Center', false, teacher_id from fx;

insert into public.memberships (company_id, user_id, role, can_teach)
select company_id, teacher_id, 'teacher'::public.member_role, true from fx
union all
select company_id, student_id, 'student'::public.member_role, false from fx
union all
select company_id, student2_id, 'student'::public.member_role, false from fx;

insert into public.homeworks (id, company_id, author_id, title, due_at)
select homework_id, company_id, teacher_id, 'Status homework', timestamptz '2026-12-01 12:00:00+00'
from fx
union all
select review_homework_id, company_id, teacher_id, 'Review homework', timestamptz '2026-12-01 12:00:00+00'
from fx
union all
select readonly_homework_id, company_id, null::uuid, 'Read-only homework', timestamptz '2026-12-01 12:00:00+00'
from fx;

insert into public.assignments (id, homework_id, company_id, student_id)
select main_id, homework_id, company_id, student_id from fx
union all
select review_id, review_homework_id, company_id, student_id from fx
union all
select stay_id, homework_id, company_id, student2_id from fx
union all
select readonly_id, readonly_homework_id, company_id, student_id from fx;

select is(
  (select status::text || ':' || current_attempt::text
     from public.assignments where id = (select main_id from fx)),
  'assigned:1',
  'a new assignment starts as assigned, attempt 1'
);

update public.assignments
   set due_at_override = timestamptz '2026-12-15 12:00:00+00'
 where id = (select stay_id from fx);

select is(
  (select status::text from public.assignments where id = (select stay_id from fx)),
  'assigned',
  'a due date override does not change the status'
);

update public.assignments set status = 'in_progress' where id = (select main_id from fx);

select ok(
  (select started_at is not null from public.assignments where id = (select main_id from fx)),
  'assigned to in_progress records started_at'
);

update public.assignments set status = 'submitted' where id = (select main_id from fx);

select is(
  (select count(*)::int from public.assignment_submissions
    where assignment_id = (select main_id from fx) and attempt_no = 1),
  1,
  'submit writes the attempt history row'
);

update public.assignments set status = 'returned' where id = (select main_id from fx);

select ok(
  (select a.current_attempt = 2 and s.outcome = 'returned'
     from public.assignments a
     join public.assignment_submissions s
       on s.assignment_id = a.id and s.attempt_no = 1
    where a.id = (select main_id from fx)),
  'a return opens attempt 2 and records the outcome'
);

update public.assignments set status = 'in_progress' where id = (select review_id from fx);
update public.assignments set status = 'submitted' where id = (select review_id from fx);
update public.assignments set status = 'reviewed' where id = (select review_id from fx);

select ok(
  (select a.status = 'reviewed' and a.reviewed_at is not null and s.outcome = 'reviewed'
     from public.assignments a
     join public.assignment_submissions s on s.assignment_id = a.id
    where a.id = (select review_id from fx)),
  'submitted to reviewed records the outcome'
);

select throws_ok(
  $$ insert into public.assignments (homework_id, company_id, student_id, status)
     select homework_id, company_id, student_id, 'submitted'::public.assignment_status
       from fx $$,
  '23514',
  null,
  'a new assignment cannot start as submitted'
);

select throws_ok(
  $$ update public.assignments set status = 'reviewed'
      where id = (select stay_id from fx) $$,
  '23514',
  null,
  'assigned cannot jump to reviewed'
);

select throws_ok(
  $$ update public.assignments set current_attempt = 2
      where id = (select stay_id from fx) $$,
  '42501',
  null,
  'state columns cannot be edited directly'
);

select throws_ok(
  $$ update public.assignments set status = 'in_progress'
      where id = (select readonly_id from fx) $$,
  '42501',
  null,
  'a homework with no author cannot leave assigned'
);

select * from finish();
rollback;
