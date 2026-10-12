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

- **Requires the user's explicit approval before it's written.** Record the approval date below. Do not write a privileged path that has no row in this file.
- Database functions live in `public` (called through `rpc` from Yoga). Service-role code lives in a dedicated Edge Function, never in Yoga.
- Identifies the caller only through `(select auth.uid())`, and validates every argument against it.
- `set search_path = ''`, fully qualified table names, explicit grants (`authenticated`, plus `anon` only when stated below).

### Not in this registry

Ordinary `security invoker` functions (the Postgres default), such as `submit_answer` or the `set_updated_at` trigger function. They run with the caller's rights, so RLS fully applies, and they need no entry.

## Registry

### RLS helpers

No RLS helper exists yet. The auth phase adds `is_member(company, roles[])`, `can_teach(company)`, `teaches(company, student)`, and `shares_event_with(user)`. Add a row here when you write each helper. Columns: function, purpose, added.

### Privileged paths

| Path | Kind | Who can call it | Why it is definer | What it allows beyond RLS | Approved |
|---|---|---|---|---|---|
| `public.handle_new_user()` | Trigger on `auth.users` | Nobody through the API. Execute is revoked from `public`, `anon`, and `authenticated`. The trigger runs it. | The auth role cannot insert into `public.profiles`. The function runs as its owner so the profile row can be inserted. | Inserts a `profiles` row for the new auth user. No company and no role. | 2026-10-07 |
| `public.preview_invite(code)` | DB function | `anon` and `authenticated` | A non-member cannot read `companies`, `profiles`, or `invites` under row policies. | Returns the company name, the inviter name, and the role for a code that is still valid. | 2026-10-07 |
| `public.redeem_invite(code)` | DB function | `authenticated` | The caller is not a member yet, so row policies would block the membership, the teacher link, the group rows, and the invite bookkeeping. | Creates the caller's membership when needed, links the inviting teacher, adds the invite's groups, and records the redemption. A failed guess is stored so the rate limit of 10 invalid codes per hour can commit. | 2026-10-07 |
