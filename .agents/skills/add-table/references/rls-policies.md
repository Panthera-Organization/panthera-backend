# RLS policy patterns

## Example

```sql
alter table public.homeworks enable row level security;

create policy "homeworks: members read"
  on public.homeworks for select to authenticated
  using (private.is_member(company_id, array['owner','admin','teacher']::public.member_role[])
         or exists (select 1 from public.assignments a
                    where a.homework_id = homeworks.id
                      and a.student_id = (select auth.uid())));

create policy "homeworks: teachers insert"
  on public.homeworks for insert to authenticated
  with check (private.is_member(company_id, array['teacher','admin','owner']::public.member_role[])
              and created_by = (select auth.uid()));

create policy "homeworks: author updates"
  on public.homeworks for update to authenticated
  using (created_by = (select auth.uid()))
  with check (created_by = (select auth.uid())
              and private.is_member(company_id, array['teacher','admin','owner']::public.member_role[]));
```

## Rules and why

- **One policy per operation.** Avoid `for all`; it hides which operation a rule was meant for.
- **`to authenticated`** on every policy. Grant `anon` only when the access matrix says so.
- **`with check` on every insert and update.** Without it, a user could change `company_id` and move a row into another tenant, or set `created_by` to someone else.
- **`(select auth.uid())`, not `auth.uid()`.** Postgres then evaluates it once per query instead of once per row.
- **Use the helpers** `private.is_member(company_id, roles[])` and `private.teaches(student_id)` instead of repeating membership subqueries.
- **Omitted operations are denied.** No delete policy for students means students can't delete. That's intentional.

## Writing an RLS helper

Helpers live in the `private` schema, which the Supabase API doesn't expose, so they can't be called directly through `/rpc`. They must meet every criterion in `docs/security-definer-registry.md` and be added to that file.

```sql
-- once, in its own migration
create schema if not exists private;
grant usage on schema private to authenticated;  -- policies run as the caller, so the caller needs usage

create function private.is_member(p_company_id uuid, p_roles public.member_role[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.memberships m
    where m.company_id = p_company_id
      and m.user_id = (select auth.uid())
      and m.role = any (p_roles)
  );
$$;

revoke execute on function private.is_member from public;
grant execute on function private.is_member to authenticated;
```

Why `security definer` here: the `memberships` policies themselves call `is_member`. With the caller's rights, the helper would trigger RLS on `memberships` again and recurse. `set search_path = ''` and fully qualified names prevent search-path attacks.

Don't put helpers in `public`, and don't give them a parameter for the caller's id: both turn a helper into something callable or abusable from outside.

## Functions that aren't helpers

- **Ordinary functions** (business logic like `submit_answer`, trigger functions like `set_updated_at`) stay `security invoker`, the default. RLS applies to them fully, and they don't go in the registry.
- **Privileged paths** (anything doing more than the caller's RLS allows) need the user's approval first. See the registry.
