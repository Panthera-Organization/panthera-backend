-- Group membership syncs teacher_students. Service role until RLS policies exist.

begin;
select plan(8);

create temp table fx (
  teacher_id  uuid,
  student_a   uuid,
  student_b   uuid,
  student_c   uuid,
  student_d   uuid,
  student_e   uuid,
  company_id  uuid,
  group_a     uuid,
  group_b     uuid,
  group_d     uuid,
  group_e     uuid
);
grant all on table fx to service_role;

insert into fx (
  teacher_id, student_a, student_b, student_c, student_d, student_e,
  company_id, group_a, group_b, group_d, group_e
) values (
  tests.create_user('teacher-groups@pgtap.panthera.local', 'Teacher'),
  tests.create_user('student-a-groups@pgtap.panthera.local', 'Student A'),
  tests.create_user('student-b-groups@pgtap.panthera.local', 'Student B'),
  tests.create_user('student-c-groups@pgtap.panthera.local', 'Student C'),
  tests.create_user('student-d-groups@pgtap.panthera.local', 'Student D'),
  tests.create_user('student-e-groups@pgtap.panthera.local', 'Student E'),
  gen_random_uuid(),
  gen_random_uuid(),
  gen_random_uuid(),
  gen_random_uuid(),
  gen_random_uuid()
);

select tests.use_service_role((select teacher_id from fx));

insert into public.companies (id, name, is_personal, created_by)
select company_id, 'Groups Center', false, teacher_id from fx;

insert into public.memberships (company_id, user_id, role, can_teach)
select company_id, teacher_id, 'teacher'::public.member_role, true from fx
union all
select company_id, student_a, 'student'::public.member_role, false from fx
union all
select company_id, student_b, 'student'::public.member_role, false from fx
union all
select company_id, student_c, 'student'::public.member_role, false from fx
union all
select company_id, student_d, 'student'::public.member_role, false from fx
union all
select company_id, student_e, 'student'::public.member_role, false from fx;

insert into public.groups (id, company_id, name, created_by)
select group_a, company_id, 'Group A', teacher_id from fx
union all
select group_b, company_id, 'Group B', teacher_id from fx
union all
select group_d, company_id, 'Group D', teacher_id from fx
union all
select group_e, company_id, 'Group E', teacher_id from fx;

insert into public.group_teachers (group_id, company_id, teacher_id)
select group_a, company_id, teacher_id from fx
union all
select group_b, company_id, teacher_id from fx
union all
select group_d, company_id, teacher_id from fx;

insert into public.group_members (group_id, company_id, student_id)
select group_a, company_id, student_a from fx;

select is(
  (select is_direct from public.teacher_students
    where teacher_id = (select teacher_id from fx)
      and student_id = (select student_a from fx)),
  false,
  'a group path creates a group-only teacher link'
);

delete from public.group_members
 where group_id = (select group_a from fx)
   and student_id = (select student_a from fx);

select is(
  (select count(*)::int from public.teacher_students
    where student_id = (select student_a from fx)),
  0,
  'removing the last group path removes the group-only link'
);

insert into public.teacher_students (company_id, teacher_id, student_id, is_direct)
select company_id, teacher_id, student_b, true from fx;

insert into public.group_members (group_id, company_id, student_id)
select group_b, company_id, student_b from fx;

delete from public.groups where id = (select group_b from fx);

select is(
  (select is_direct from public.teacher_students
    where student_id = (select student_b from fx)),
  true,
  'deleting the group keeps a direct teacher link'
);

insert into public.teacher_students (company_id, teacher_id, student_id, is_direct)
select company_id, teacher_id, student_c, true from fx;

select public.unlink_teacher_student(
  (select company_id from fx),
  (select teacher_id from fx),
  (select student_c from fx)
);

select is(
  (select count(*)::int from public.teacher_students
    where student_id = (select student_c from fx)),
  0,
  'unlink removes a direct link that has no group path'
);

insert into public.teacher_students (company_id, teacher_id, student_id, is_direct)
select company_id, teacher_id, student_d, true from fx;

insert into public.group_members (group_id, company_id, student_id)
select group_d, company_id, student_d from fx;

select public.unlink_teacher_student(
  (select company_id from fx),
  (select teacher_id from fx),
  (select student_d from fx)
);

select is(
  (select is_direct from public.teacher_students
    where student_id = (select student_d from fx)),
  false,
  'unlink keeps the link when a group path remains'
);

insert into public.group_members (group_id, company_id, student_id)
select group_e, company_id, student_e from fx;

insert into public.group_teachers (group_id, company_id, teacher_id)
select group_e, company_id, teacher_id from fx;

select is(
  (select is_direct from public.teacher_students
    where student_id = (select student_e from fx)),
  false,
  'adding a teacher to a group with a student creates the link'
);

delete from public.group_teachers
 where group_id = (select group_e from fx)
   and teacher_id = (select teacher_id from fx);

select is(
  (select count(*)::int from public.teacher_students
    where student_id = (select student_e from fx)),
  0,
  'removing the teacher removes the group-only link'
);

insert into public.group_teachers (group_id, company_id, teacher_id)
select group_e, company_id, teacher_id from fx;

delete from public.groups where id = (select group_e from fx);

select is(
  (select count(*)::int from public.teacher_students
    where student_id = (select student_e from fx)),
  0,
  'deleting the group removes a group-only link'
);

select * from finish();
rollback;
