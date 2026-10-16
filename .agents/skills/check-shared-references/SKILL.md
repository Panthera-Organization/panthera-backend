---
name: check-shared-references
description: >-
  Check a planned change against the Panthera documents in the Shared
  references Linear project before writing it. Use when adding a feature or
  screen, or when a task touches RLS policies, grants, business rules,
  triggers, database structure, migrations, enums, foreign keys, on-delete
  behavior, security definer functions, the service role, Storage, Realtime,
  RPCs, GraphQL fields, roles, memberships, invites, join requests, sharing,
  groups, the personal workspace, account deletion, navigation, or an
  important project decision. If the change conflicts with those documents,
  touches an open (❓) or deferred decision, or builds a backlog item, stop
  and ask the user, with the conflict, the explanation, and the effects.
---

# Check shared references

Do this before you write the change. Don't write the conflicting part first and ask afterwards.

## 0. Run the check in a subagent

The documents are long. Your own context only needs the rules that apply. **If you can start a subagent** (Task/Agent tool), give it sections 1–3 of this skill, a precise description of the planned change (tables, functions, policies, screens, GraphQL fields), the repo name and the current phase. Ask it to return **only the report below**, under 400 words, and not the documents themselves. Then continue from section 4 with that report. If a rule in the report is unclear, ask the subagent or fetch that one document. Don't re-fetch everything.

If you can't start a subagent, do sections 1–3 yourself, and keep only the report in your working notes.

```
Verdict: MATCH | CONFLICT | MISSING DECISION
Phase: <Pn, doc ID>
Rules relied on:
- <ID> (<Doc ID>): <the rule in one line>
Conflicts:            (omit if none)
- <what disagrees> | Docs: <rule, ID> | Change: <planned behavior> | Effects: <…>
Missing decisions:    (omit if none)
- <what's open> (<ID or BL-41>) | Options: <recommended first>
Warnings:             (omit if none)
- <index missing a doc, registry mirror mismatch, fetch failure>
Docs fetched: <Doc IDs>
```

## 1. Fetch

The documents live in the Linear project **Shared references** (`projectId` `P-PB-1`). Each one starts with a header: `Doc ID`, `Status`, `Updated`, `Fetch when`.

1. Call `list_documents` with `projectId` `P-PB-1`. Keep the titles; don't fetch them all.
2. Fetch the index: the document whose title starts with `00 Index` (`Doc ID: IDX`). It holds the precedence rules, the doc map with "Fetch when", the glossary and the editing rules.
3. Using the doc map's "Fetch when" column, fetch every document that matches the change:
   * the plan doc for the current phase (`PLAN-01`…`PLAN-04`), or `PLAN-00` when no phase applies. **Skip plan docs whose header says `Status: Done`**, unless the change alters work from that phase;
   * every `DEC-*` doc whose topic the change touches, plus the docs that the phase doc cites by decision ID. **When unsure whether a `DEC-*` doc applies, fetch it.** Missing a rule costs more than a few extra tokens;
   * `SEC-40` when the change touches privileges, definer functions, the service role, RLS helpers, Storage or grants;
   * `ERD-25` only for migrations or schema design;
   * `BL-41` only when you're adding behavior that the phase doc doesn't mention;
   * in `panthera-app`: `PRD-10`/`PRD-11` for screen or navigation work, and `PRD-12` for theme or strings;
   * **never `IDX-LOG`** (the changelog), unless the user asks about history.
4. A title from `list_documents` that isn't in the doc map: fetch it once, and report "index is missing <title>" under Warnings. Skip a title that starts with `Deprecated —`. Those documents stay for the migration. They are not part of the check, and they are not missing from the index.

If the list or a needed document can't be fetched, stop and report it. Don't guess a decision.

**Registry mirror (`panthera-backend` only).** If you fetched `SEC-40`, compare it with `docs/security-definer-registry.md`. Linear is canonical. Report any difference under Warnings.

## 2. Precedence

Use the precedence in `IDX` §2. As of 2026-10-16:

1. Decisions marked **🛠 pending migration** are the target state. Here the SQL is *expected* to differ. Implement the decision; this is not a conflict.
2. SQL migrations in `panthera-backend`: the truth for what's already built.
3. Decisions marked **✅**.
4. Product docs (`PRD-*`). A `DEC-*` wins over them. Flag the disagreement.
5. Plan docs (`PLAN-*`).
6. The architecture doc: only for stack, repos, CI and conventions.

If `IDX` states a different order, follow `IDX`.

## 3. Compare

Check at least the points that apply to this change:

* **Access:** each role (owner > admin > teacher > student, `TEN-13`), another company, and `anon`.
* **Privileges:** a new or changed `security definer` function, trigger or service-role path. A privileged path without an approved `SEC-40` row is a conflict. An RLS helper must meet every helper criterion in `SEC-40`; if it does, it only needs registering.
* **Writes:** whether a partial write is acceptable, or it must be one invoker RPC (`PLT-03`).
* **Realtime / Storage / grants:** only `assignments` is published; bucket paths; the 25 MB file limit.
* **Tenancy:** the personal-workspace invariants (`TEN-04`, `TEN-04a`, `TEN-06`); invites create join requests (`TEN-24`); leave, delete and cascade rules (`TEN-07`…`TEN-12`); multi-workspace `companyIds` and per-item `viewerCan` (`TEN-10`, `PLT-09`).
* **Content:** live sharing to audiences (`CON-01`) versus snapshots (`CON-05`, `TEN-32`). Exercises and lesson plans never reach students.
* **Status of what you rely on:** a decision marked ❓ open or ⏸ deferred, an item in `BL-41`, or an unfinished "First task: close …" in the phase doc → **MISSING DECISION**.

## 4. Match

Continue the task. Tell the user in one or two sentences that the change matches, and name the decision IDs from the report (e.g. "Matches `TEN-24`, `SEC-40`"). Cite the same IDs in the PR description, and in code comments where a rule is non-obvious (e.g. `-- TEN-24: uses counted on approval`).

## 5. Conflict or missing decision

Stop. Don't apply the change. Don't edit the Linear documents or the registry to hide the conflict. Ask:

```
Conflict: <what disagrees>
Documents say: <the rule> (<decision ID>, <Doc ID>)
This change would: <the planned behavior>
Effects if we do it: <what breaks, what becomes possible, which later phase or decision changes>
Do you approve this change?
```

or

```
Missing decision: <what has to be decided> (<decision ID or BL-41>)
Options: <2–3 options, the recommended one first, with effects>
Which one do we go with?
```

Wait for the answer.

## 6. After the user decides

**Approved (or a decision made):** follow it, then update the documents, using the rules in `IDX` §5:

* Rewrite the decision **in place under the same ID**, and set its marker (usually 🛠 plus the phase). No "previously…" or "supersedes…" notes. A new decision gets the next free ID with that doc's prefix. Never reuse a removed ID.
* **Append one line to `IDX-LOG`** with the date and the change. Don't put history anywhere else.
* New gap or RPC → add it to the `PLAN-00` tables and to the phase doc's tasks.
* Set the header's `Updated` date. Keep each doc under ~2.5k tokens. If one grows past that, propose a split to the user.
* Registry: update **`SEC-40` in Linear first**, then `docs/security-definer-registry.md` **in the same PR**. A privileged path gets its approval date in its row.
* A new document also gets a row in the `IDX` doc map, with "Fetch when".
* A phase finished → set its row in `PLAN-00` to `Done`. When every phase in a plan doc is done, set that doc's header to `Status: Done`.

**Refused:** keep the documents and change the plan.
