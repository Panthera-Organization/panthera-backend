-- Last-owner protection and personal-company deletion. Service role until RLS policies exist.

begin;
select plan(5);

create temp table fx (
  owner_id          uuid,
  owner2_id         uuid,
  personal_owner_id uuid,
  stay_owner_id     uuid,
  student_id        uuid,
  center_id         uuid,
  personal_id       uuid,
  stay_id           uuid
);
grant all on table fx to service_role;

insert into fx (
  owner_id, owner2_id, personal_owner_id, stay_owner_id, student_id,
  center_id, personal_id, stay_id
) values (
  tests.create_user('owner-center@pgtap.panthera.local', 'Owner'),
  tests.create_user('owner2-center@pgtap.panthera.local', 'Second Owner'),
  tests.create_user('owner-personal@pgtap.panthera.local', 'Personal Owner'),
  tests.create_user('owner-stay@pgtap.panthera.local', 'Stay Owner'),
  tests.create_user('student-owner@pgtap.panthera.local', 'Student'),
  gen_random_uuid(),
  gen_random_uuid(),
  gen_random_uuid()
);

select tests.use_service_role(null);

insert into public.companies (id, name, is_personal, created_by)
select center_id, 'Owner Center', false, owner_id from fx
union all
select personal_id, 'Personal Workspace', true, personal_owner_id from fx
union all
select stay_id, 'Stay Workspace', true, stay_owner_id from fx;

insert into public.memberships (company_id, user_id, role, can_teach)
select center_id, owner_id, 'owner'::public.member_role, false from fx
union all
select personal_id, personal_owner_id, 'owner'::public.member_role, true from fx
union all
select personal_id, student_id, 'student'::public.member_role, false from fx
union all
select stay_id, stay_owner_id, 'owner'::public.member_role, true from fx
union all
select stay_id, student_id, 'student'::public.member_role, false from fx;

select throws_ok(
  $$ delete from public.memberships
      where company_id = (select center_id from fx)
        and user_id = (select owner_id from fx) $$,
  '23514',
  null,
  'the last owner of a center cannot leave'
);

select throws_ok(
  $$ update public.memberships set role = 'admin'
      where company_id = (select center_id from fx)
        and user_id = (select owner_id from fx) $$,
  '23514',
  null,
  'the last owner of a center cannot be demoted'
);

insert into public.memberships (company_id, user_id, role, can_teach)
select center_id, owner2_id, 'owner'::public.member_role, false from fx;

delete from public.memberships
 where company_id = (select center_id from fx)
   and user_id = (select owner_id from fx);

select is(
  (select count(*)::int from public.memberships
    where company_id = (select center_id from fx) and role = 'owner'),
  1,
  'one owner can leave when another owner remains'
);

delete from public.memberships
 where company_id = (select personal_id from fx)
   and user_id = (select personal_owner_id from fx);

select is(
  (select count(*)::int from public.companies where id = (select personal_id from fx)),
  0,
  'deleting the owner of a personal workspace deletes that workspace'
);

delete from public.memberships
 where company_id = (select stay_id from fx)
   and user_id = (select student_id from fx);

select is(
  (select count(*)::int from public.companies where id = (select stay_id from fx)),
  1,
  'a student leaving a personal workspace does not delete it'
);

select * from finish();
rollback;
