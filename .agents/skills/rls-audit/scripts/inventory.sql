-- RLS audit inventory. Run against the local database:
--   psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -f scripts/inventory.sql

\echo '== Tables without RLS (must be empty) =='
select tablename from pg_tables
where schemaname = 'public' and not rowsecurity;

\echo '== Policies =='
select schemaname, tablename, policyname, cmd, roles, qual, with_check
from pg_policies
where schemaname in ('public', 'storage')
order by tablename, cmd;

\echo '== Security definer functions (compare with docs/security-definer-registry.md) =='
select n.nspname as schema, p.proname, p.provolatile as volatility,
       pg_get_function_result(p.oid) as returns, p.proconfig as settings
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where p.prosecdef
  and n.nspname not in ('pg_catalog', 'information_schema', 'auth', 'storage',
                        'realtime', 'extensions', 'graphql', 'graphql_public',
                        'pgbouncer', 'vault', 'supabase_functions', 'net', 'cron')
order by n.nspname, p.proname;

\echo '== Function execute grants =='
select routine_schema, routine_name, grantee, privilege_type
from information_schema.routine_privileges
where routine_schema in ('public', 'private')
order by routine_schema, routine_name, grantee;

\echo '== Views and their options (need security_invoker=true) =='
select c.relname, c.reloptions
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind = 'v';

\echo '== Tables published to Realtime =='
select tablename from pg_publication_tables where pubname = 'supabase_realtime';
