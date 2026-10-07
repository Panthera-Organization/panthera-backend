---
name: add-graphql-field
description: Add or change a GraphQL query field, type, enum or mutation in Panthera's Yoga API (panthera-backend) end to end — schema, codegen, DataLoader, resolver, tests and breaking-change check. Use whenever a task touches schema.graphql, resolvers or loaders, or whenever the app needs data or an action the API doesn't offer yet, even if GraphQL isn't mentioned.
---

# Add a GraphQL field or mutation

Yoga runs inside a Supabase Edge Function as the signed-in user. Postgres RLS decides visibility; Yoga only shapes data. The schema lives only in `supabase/functions/_shared/graphql/schema.graphql`.

## Before you start

- If the field needs a table or column that doesn't exist, run `add-table` first.
- Design the field around what a screen needs, not as a copy of a table.

## Steps

1. Design and add the field to `schema.graphql`, following `references/schema-design.md`. Changes are additive only.
2. Run `npx graphql-codegen`. Add a `mappers` entry in `codegen.ts` if a new type maps to a DB row.
3. Add DataLoaders for every nested field, using `references/dataloader-patterns.ts`.
4. Write the resolver following `references/resolver-template.ts`.
5. Add an integration test from `references/integration-test.ts`. Also run `supabase test db` if SQL changed.
6. Run the breaking-change check:
   `npx graphql-inspector diff 'git:origin/main:supabase/functions/_shared/graphql/schema.graphql' supabase/functions/_shared/graphql/schema.graphql`

## Rules

- Every object type has `id: ID!`. The app's Apollo cache depends on it.
- Mutations take one `input` argument and return the changed objects with `id`, including related objects whose fields changed.
- Nested resolvers use `ctx.loaders`, never `ctx.supabase` directly. Loaders are created per request, never at module level.
- Use only `ctx.supabase` and `ctx.loaders`. **Never the service role.**
- Database functions called with `rpc` are `security invoker` by default, so RLS applies. Only a **privileged path** from `docs/security-definer-registry.md` may be `security definer`, and a new one needs the user's approval first.
- Don't re-implement access rules in resolvers, and keep business rules (status transitions) in the database.
- If Inspector reports a breaking change, stop and propose a non-breaking alternative (deprecate + add).

## Done when

- [ ] The schema change is additive (or the user explicitly accepted a breaking change)
- [ ] Codegen runs clean and the type-check passes
- [ ] Nested fields use loaders
- [ ] The integration test passes as an allowed user and as a denied user

## Report

Give the user: the schema diff, the loaders added, test results, and the hand-off: after merge and deploy, a bot PR updates `schema.graphql` in `panthera-app`. For app work before that, set `GRAPHQL_SCHEMA_PATH` in the app to this repo's schema file.

## References

- `references/schema-design.md`: naming, nullability, mutations, deprecation. Read in step 1.
- `references/dataloader-patterns.ts`: by-id and one-to-many loaders. Read in step 3.
- `references/resolver-template.ts`: resolver shape and error handling. Read in step 4.
- `references/integration-test.ts`: testing through Yoga as different users. Read in step 5.
