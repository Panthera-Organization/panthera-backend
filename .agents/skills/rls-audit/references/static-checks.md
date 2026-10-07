# Static checks

Flag each of these in the inventory:

| Check | Why it matters |
|---|---|
| Table in `public` without RLS | Anyone with the anon key can read it. Always critical |
| `for all` policy | Hides which operation a rule was meant for. Check each operation separately |
| Insert or update policy without `with check` | A user may change `company_id` to move a row into another tenant, or set `created_by` to someone else |
| Policy granted to `public` or `anon` | Only acceptable where the access matrix says so |
| `using (true)`, or no reference to `auth.uid()`, a helper or the tenant | Effectively open to everyone in that role |
| `security definer` function not in `docs/security-definer-registry.md` | Unreviewed elevated code |
| Registered RLS helper breaking a helper criterion (in `public`, not `stable`/`sql`/`boolean`, writes data, takes the caller's id) | No longer a harmless predicate |
| `private` listed under `[api] schemas` in `supabase/config.toml` | Helpers become callable through `/rpc` |
| Privileged path without a recorded approval | Unapproved exception to the security model |
| `security definer` function without `set search_path = ''` | Vulnerable to search-path attacks |
| `security definer` function with unqualified table names | Same risk |
| `security definer` function executable by `public` | Callable by anyone, including `anon` |
| Function trusting a `user_id` argument for the caller | Must use `auth.uid()` for the caller, not a parameter |
| Business-logic function (e.g. `submit_answer`) declared `security definer` | Should be `security invoker` so RLS applies |
| View without `security_invoker = true` | Runs as its owner and bypasses RLS |
| Realtime table with broad select policies | Realtime delivers changes according to select policies |
| Storage policy checking only `auth.role() = 'authenticated'` | Must check membership through the object path (for example `<company_id>/...`) |
