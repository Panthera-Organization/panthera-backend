-- Smoke test: proves pgTAP runs against the migrated local database.
begin;
select plan(1);

select has_table(
  'public',
  'profiles',
  'frozen schema creates public.profiles'
);

select * from finish();
rollback;
