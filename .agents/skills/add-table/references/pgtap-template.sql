-- supabase/tests/<table>_rls.test.sql
-- Outcomes to remember:
--   select filtered by RLS        → zero rows (not an error)
--   insert/update blocked by RLS  → error 42501

begin;
select plan(4);  -- update to the number of assertions

-- Fixtures: insert as postgres, before switching role
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'teacher@a.test'),
  ('00000000-0000-0000-0000-00000000000b', 'teacher@b.test'),
  ('00000000-0000-0000-0000-00000000000c', 'student@a.test');
-- ... companies A and B, memberships, rows for both companies ...

-- Allowed: teacher A reads own company
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}';

select results_eq(
  $$ select count(*)::int from public.homeworks $$,
  array[1],
  'teacher A sees only company A rows'
);

-- Cross-tenant: teacher A cannot write into company B
select throws_ok(
  $$ insert into public.homeworks (company_id, created_by, title, due_at)
     values ('<company B id>', '00000000-0000-0000-0000-00000000000a', 'x', now()) $$,
  '42501', null,
  'teacher A cannot insert into company B'
);

-- Wrong role: student cannot insert
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-00000000000c","role":"authenticated"}';
select throws_ok(
  $$ insert into public.homeworks (company_id, created_by, title, due_at)
     values ('<company A id>', '00000000-0000-0000-0000-00000000000c', 'x', now()) $$,
  '42501', null,
  'student cannot create homework'
);

-- Anonymous: sees nothing
reset role;
set local role anon;
select is_empty($$ select 1 from public.homeworks $$, 'anon sees nothing');

reset role;
select * from finish();
rollback;
