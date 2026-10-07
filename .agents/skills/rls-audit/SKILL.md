---
name: rls-audit
description: Audit Panthera's database security — RLS policies, security definer functions, grants, views, Storage policies and Realtime exposure — against the intended access matrix, and attack it with pgTAP tests. Use whenever the user asks to audit, review or check RLS, permissions or tenant isolation, before a release, after a batch of migrations, or asks "can a student see X?" about panthera-backend.
---

# RLS audit

Panthera is multi-tenant and some users are children. Treat the database as an attacker would: nothing is safe until a test proves it.

**The output is a report with proposed fixes. Don't change policies or functions without the user's approval.**

**An open finding is a vulnerability.** Treat it like one: nothing that describes or proves an unfixed finding may end up in git history, a PR, an issue, or anywhere else that is (or may later become) public. The repo may be made public one day, and its whole history goes with it.

## Before you start

Find the intended access matrix (`docs/access-matrix.md`, ADRs, or migration comments). If none exists, reconstruct one from the migrations, **show it to the user, and get confirmation** before auditing against it.

## Steps

1. Run `supabase start`, then run `scripts/inventory.sql` against the local database (default `postgresql://postgres:postgres@127.0.0.1:54322/postgres`; confirm with `supabase status`).
2. Go through the inventory with `references/static-checks.md` and note every finding.
3. Compare every `security definer` function from the inventory, and every hit of `grep -rn "SERVICE_ROLE" supabase/`, with `docs/security-definer-registry.md`. Check that `private` is not listed under `[api] schemas` in `supabase/config.toml`.
4. Write attack tests in `.audit/audit_<table>.test.sql`, covering every applicable row of `references/attack-catalog.md`. Do not create them under `supabase/tests/` yet.
5. Run `supabase test db .audit/audit_<table>.test.sql` for each file. A passing test means the attack was blocked; a failing test is a finding.
6. Copy only passing tests to `supabase/tests/audit_<table>.test.sql`. Leave every failing test in `.audit/`. If one file mixes both, split it: `supabase/tests/` gets only the assertions that passed, and `.audit/` keeps the ones that failed.
7. Write the report to `.audit/rls-audit-<date>.md` using `assets/report-template.md`, and give the user the summary in the conversation. Never commit the report.

## Rules

- `docs/security-definer-registry.md` is the only list of allowed elevated code. Don't keep or trust any other list.
- **Findings:** an unregistered `security definer` function or service-role use; a registered RLS helper that breaks any helper criterion (for example it lives in `public`, writes data, or takes the caller's id as a parameter); a privileged path without a recorded approval; a `security definer` function in `public` registered as a helper.
- A registered helper that meets every criterion is **not** a finding.
- Propose fixes as SQL in the report, but never apply them unasked.
- Keep the attack tests in the repo after fixes, so CI guards against regressions.

## Where results go

| Output | Where | Why |
|---|---|---|
| Passing attack tests (attack blocked) | Copy to `supabase/tests/`, then commit | Regression guards; they reveal nothing exploitable |
| Failing attack tests (open finding) | `.audit/` only, never committed | A failing test is a working exploit |
| Report | `.audit/rls-audit-<date>.md`, never committed | Describes findings, including ones already fixed |
| Tracking open findings | A **draft GitHub security advisory** on the repo, created by the user | Drafts stay private even in a public repo |

- `.audit/` must be in `.gitignore`. If it isn't, add it before writing anything there.
- **Don't** open issues, PRs, commits or PR descriptions that describe an open finding, and don't put findings in commit messages.
- **The fix and its test land together.** When the user approves a fix, re-run the test from `.audit/`. Only after it passes, move it into `supabase/tests/` in the **same PR** as the fix, so it never reaches history as a failing test. Describe that PR neutrally (for example "tighten homeworks update policy"), not as an exploit.
- If this audit runs as a cloud agent with no private place to write, put the report only in the agent's final message to the user, never in a PR or issue.

## Done when

- [ ] The access matrix is confirmed by the user
- [ ] Every public table, function, view, Storage bucket and Realtime table has been checked
- [ ] Every `security definer` function matches the registry and its class criteria
- [ ] Attack tests exist for every table: passing ones copied to `supabase/tests/`, failing ones only in `.audit/`
- [ ] The report is in `.audit/`, with severities and proposed fixes, and is not staged or committed
- [ ] Nothing describing an open finding is staged, committed, or in a PR or issue (check `git status`)

## References

- `scripts/inventory.sql`: queries for tables, policies, functions, grants, views and Realtime. Step 1.
- `docs/security-definer-registry.md` (in the repo): helper criteria and the registry. Step 3.
- `references/static-checks.md`: what to flag in the inventory. Step 2.
- `references/attack-catalog.md`: attacks to test. Step 4.
- `assets/report-template.md`: report structure and severity guide. Step 7.
