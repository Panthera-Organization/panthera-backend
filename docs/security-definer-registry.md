# Security definer registry

The single list of every function that runs with more privileges than its caller. The `add-table`, `add-graphql-field` and `rls-audit` skills all read this file; none of them keeps its own list.

**Rule:** every `security definer` function in the database, and every Edge Function using the service role, appears here. Anything missing from this file is an audit finding.

## Classes

### RLS helper

A read-only yes/no question about the caller, used inside RLS policies. It's `security definer` so policies on tables like `memberships` can call it without recursing into their own RLS.

All criteria must hold:

- Lives in the `private` schema, which is **not** exposed through the Supabase API (not listed under `[api] schemas` in `supabase/config.toml`).
- `language sql`, `stable`, returns `boolean`.
- Never writes data.
- Identifies the caller only through `(select auth.uid())`. It never accepts the caller's id as a parameter.
- `set search_path = ''`, fully qualified table names.
- `execute` revoked from `public`, granted to `authenticated` only.

Adding a helper that meets every criterion doesn't need prior approval, but it must be added to this file and mentioned in the PR description.

### Privileged path

Performs an action, or returns data, beyond what the caller's RLS rights allow. These are deliberate exceptions to the security model.

- **Requires the user's explicit approval before it's written.** Record the approval date below.
- Database functions live in `public` (called through `rpc` from Yoga). Service-role code lives in a dedicated Edge Function, never in Yoga.
- Identifies the caller only through `(select auth.uid())`, and validates every argument against it.
- `set search_path = ''`, fully qualified table names, explicit grants (`authenticated`, plus `anon` only when stated below).

### Not in this registry

Ordinary `security invoker` functions (the Postgres default), such as `submit_answer` or the `set_updated_at` trigger function. They run with the caller's rights, so RLS fully applies, and they need no entry.

## Registry

### RLS helpers

| Function | Purpose | Added |
|---|---|---|
| `private.is_member(company_id, roles[])` | Is the caller a member of the company with one of these roles? | <date> |
| `private.teaches(student_id)` | Does the caller teach this student (in any shared company)? | <date> |

### Privileged paths

| Path | Kind | Grants to | What it allows beyond RLS | Approved |
|---|---|---|---|---|
| `public.handle_new_user()` | Trigger on `auth.users` | none (revoked from `public`, `anon`, `authenticated`) | Inserts a `profiles` row for the new auth user. No company and no role | 2026-10-07 |
| `public.preview_invite(code)` | DB function | `anon`, `authenticated` | Shows company and teacher name for a valid invite code to a non-member | 2026-10-07 |
| `public.redeem_invite(code)` | DB function | `authenticated` | Creates the caller's membership and teacher link from a valid invite | 2026-10-07 |
| `delete-account` | Edge Function (service role) | `authenticated` (own account only) | Deletes the caller's auth user via the admin API | <date> |
