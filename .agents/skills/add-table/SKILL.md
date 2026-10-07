---
name: add-table
description: Add or change a Postgres table in panthera-backend — migration, Row Level Security policies, pgTAP RLS tests and regenerated database types, delivered together as one change. Use whenever a task creates a table, adds or changes columns, enums, foreign keys or on-delete behavior, or touches supabase/migrations, even if the user only says "we need to store X".
---

# Add or change a table

Every table holds multi-tenant data protected by RLS. A table change is complete only when the migration, the policies, the tests and the regenerated types land together.

## Before you start

Write the **access matrix**: roles (`owner`, `admin`, `teacher`, `student`, other company's member, `anon`) × `select / insert / update / delete`, with conditions. If the task doesn't define it, **propose one and ask the user to confirm**. Access rules are a human decision.

Also decide, and record as comments in the migration:
- **Who writes the table.** If students and teachers write different columns, split it into two tables by writer.
- **On-delete behavior** for each foreign key, and why.

## Steps

1. `supabase migration new <snake_case_name>`, then write the table using `references/migration-template.sql`.
2. Enable RLS and write one policy per operation, following `references/rls-policies.md`.
3. Write `supabase/tests/<table>_rls.test.sql` from `references/pgtap-template.sql`, covering allowed, cross-tenant, wrong-role and `anon` cases.
4. Run `supabase db reset` and `supabase test db`. Both must pass.
5. Run `supabase gen types typescript --local > supabase/functions/_shared/db/database.types.ts`.

## Rules

- Tenant tables have `company_id uuid not null`. There is no nullable company; standalone teachers have a personal company.
- Times are `timestamptz`. Files are stored as Storage **paths**, not URLs. Fixed value sets are enums.
- Index every foreign key column.
- Lifecycle rules (status transitions) are enforced in the database, not only in the app.
- Never use the service role to get around RLS.
- `security definer` functions follow `docs/security-definer-registry.md`. An **RLS helper** (in `private`, meeting every criterion there) may be added without prior approval but must be registered. A **privileged path** needs the user's approval before you write it. Ordinary functions stay `security invoker` (the default).
- **Expand / contract:** add freely, but never rename, drop or make a column `not null` without a default in one step. If the task needs that, propose a two-release plan.

## Done when

- [ ] The access matrix is confirmed by the user
- [ ] The migration applies cleanly on `supabase db reset`
- [ ] RLS is enabled, with a policy for each supported operation
- [ ] pgTAP tests pass, including the denial cases
- [ ] DB types are regenerated
- [ ] Any new `security definer` function is in `docs/security-definer-registry.md`

## Report

Give the user: the implemented access matrix (table), on-delete choices, any new RLS helper (registered) or privileged path (approved) — flag both for review, and test results. If the table should be exposed in the API, continue with `add-graphql-field`.

## References

- `references/migration-template.sql`: table conventions. Read in step 1.
- `references/rls-policies.md`: policy patterns, pitfalls and how to write an RLS helper. Read in step 2.
- `docs/security-definer-registry.md` (in the repo): the helper criteria and the registry. Read before adding any `security definer` function.
- `references/pgtap-template.sql`: test structure. Read in step 3.
