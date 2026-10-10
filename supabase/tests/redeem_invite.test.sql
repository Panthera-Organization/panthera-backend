-- Every redeem_invite result. Service role until RLS policies exist.
-- A second ok is possible only while uses remain. The exhausted check runs first.

begin;
select plan(15);

create temp table fx (
  owner_id    uuid,
  teacher_id  uuid,
  student_id  uuid,
  invalid_id  uuid,
  rate_id     uuid,
  company_id  uuid
);
grant all on table fx to service_role;

insert into fx (owner_id, teacher_id, student_id, invalid_id, rate_id, company_id)
values (
  tests.create_user('owner-invite@pgtap.panthera.local', 'Owner'),
  tests.create_user('teacher-invite@pgtap.panthera.local', 'Teacher'),
  tests.create_user('student-invite@pgtap.panthera.local', 'Student'),
  tests.create_user('invalid-invite@pgtap.panthera.local', 'Invalid'),
  tests.create_user('rate-invite@pgtap.panthera.local', 'Rate'),
  gen_random_uuid()
);

select tests.use_service_role((select owner_id from fx));

insert into public.companies (id, name, is_personal, created_by)
select company_id, 'Invite Center', false, owner_id from fx;

insert into public.memberships (company_id, user_id, role, can_teach)
select company_id, owner_id, 'owner'::public.member_role, true from fx
union all
select company_id, teacher_id, 'teacher'::public.member_role, true from fx;

insert into public.invites (code, company_id, created_by, role, max_uses, expires_at)
select '23456789', company_id, owner_id, 'student'::public.member_role, 2, now() + interval '7 days' from fx
union all
select '2345678A', company_id, owner_id, 'student'::public.member_role, 1, now() + interval '7 days' from fx
union all
select '2345678B', company_id, owner_id, 'student'::public.member_role, 1, now() - interval '1 hour' from fx
union all
select '2345678C', company_id, owner_id, 'student'::public.member_role, 1, now() + interval '7 days' from fx
union all
select '2345678D', company_id, owner_id, 'student'::public.member_role, 1, now() + interval '7 days' from fx
union all
select '2345678F', company_id, owner_id, 'student'::public.member_role, 1, now() + interval '7 days' from fx;

update public.invites set revoked_at = now() where code = '2345678C';
update public.invites set use_count = 1 where code = '2345678D';

insert into public.invite_failed_attempts (user_id)
select rate_id from fx, generate_series(1, 10);

select tests.use_service_role((select student_id from fx));

select results_eq(
  $$ select result::text, company_id::text from public.redeem_invite('23456789') $$,
  $$ select 'ok'::text, company_id::text from fx $$,
  'a valid invite returns ok for its company'
);

select is(
  (select role::text from public.memberships
    where company_id = (select company_id from fx)
      and user_id = (select student_id from fx)),
  'student',
  'ok creates the student membership'
);

select is(
  (select is_direct from public.teacher_students
    where teacher_id = (select owner_id from fx)
      and student_id = (select student_id from fx)),
  true,
  'ok links the student to the teaching inviter'
);

select is(
  (select result::text from public.redeem_invite('23456789')),
  'ok',
  'the same user can redeem that invite again while uses remain'
);

select is(
  (select use_count from public.invites where code = '23456789'),
  1,
  'a repeat redeem does not consume another use'
);

select tests.use_service_role((select teacher_id from fx));

select is(
  (select result::text from public.redeem_invite('2345678A')),
  'role_conflict',
  'a different role for an existing member is a role conflict'
);

select is(
  (select role::text from public.memberships
    where company_id = (select company_id from fx)
      and user_id = (select teacher_id from fx)),
  'teacher',
  'role_conflict does not change the membership'
);

select is(
  (select use_count from public.invites where code = '2345678A'),
  0,
  'role_conflict does not consume a use'
);

select is(
  (select result::text from public.redeem_invite('2345678B')),
  'expired',
  'an expired invite returns expired'
);

select is(
  (select result::text from public.redeem_invite('2345678C')),
  'revoked',
  'a revoked invite returns revoked'
);

select is(
  (select result::text from public.redeem_invite('2345678D')),
  'exhausted',
  'an invite with no uses left returns exhausted'
);

select tests.use_service_role((select invalid_id from fx));

select is(
  (select result::text from public.redeem_invite('2345678E')),
  'invalid',
  'an unknown code returns invalid'
);

select is(
  (select count(*)::int from public.invite_failed_attempts
    where user_id = (select invalid_id from fx)),
  1,
  'an invalid code records a failed attempt'
);

select tests.use_service_role((select rate_id from fx));

select is(
  (select result::text from public.redeem_invite('2345678F')),
  'rate_limited',
  'ten failed attempts in an hour return rate_limited'
);

select tests.use_service_role(null);

select throws_ok(
  $$ select * from public.redeem_invite('23456789') $$,
  '28000',
  null,
  'redeem requires a signed-in user'
);

select * from finish();
rollback;
