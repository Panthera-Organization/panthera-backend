---
name: check-shared-references
description: >-
  Check a planned change against every document in the Shared references
  Linear project before writing it. Use when adding a feature, or when a task touches
  RLS policies, grants, business rules, triggers, database structure,
  migrations, enums, foreign keys, on-delete behavior, security definer
  functions, the service role, Storage policies, Realtime, RPCs,
  GraphQL access, roles, memberships, invites, account deletion, or an
  important project decision. If the change conflicts with those
  documents, stop and ask the user to approve it, with the conflict,
  the explanation, and the effects.
---

# Check shared references

Do this before you write the change. Do not write the conflicting part first and ask after.

## Fetch

Fetch every document on the Linear project **Shared references** (Panthera Backend and Panthera App). Call `list_documents` with `projectId` `P-PB-1`. Then call `get_document` for each document in that list. Do not use a fixed list of titles. A document added to the project later is part of the check.

Also read `docs/security-definer-registry.md` in this repo. The skills read that file. If the project contains a registry document, the repo file must match it.

If the list or any document cannot be fetched, stop and say so. Do not guess the decision.

## Precedence

When sources disagree, use the precedence written in the fetched documents. Until a fetched document states otherwise, the higher source wins:

1. The SQL schema in this repo
2. The decisions document in Shared references
3. The architecture doc, where the other two are silent

The plan document says how to build. The registry document lists every function that runs with more rights than its caller.

## Compare

Compare the planned change with those documents. Check at least:

- Who can read or write the data, including another company and `anon`
- Roles, `can_teach`, invites, and what happens when a member leaves
- On-delete behavior and cascades
- A new or changed `security definer` function, trigger, or service-role path
- Whether a partial write is allowed, or the write must be one invoker RPC
- Realtime publication, Storage paths, and grants

A new privileged path with no row breaks the rule in `docs/security-definer-registry.md`. Treat that as a conflict.

## No conflict

Continue the task. Tell the user, in one or two sentences, that the change matches the Shared references documents.

## Conflict

Stop. Do not apply the conflicting change. Do not edit the Linear documents or the registry to hide the conflict. Ask the user to approve it in this shape:

```
Conflict: <what disagrees>
Documents say: <the rule, and which document>
This change would: <the planned behavior>
Effects if we do it: <what breaks, what becomes possible, what later phase changes>
Do you approve this change?
```

Wait for the answer. When the approval adds or changes a privileged path, add the row to `docs/security-definer-registry.md` and to the Linear registry document in that same change. Write the function only after both copies contain the row. For any other approval, follow the approved side and update each fetched document that the decision changes. On refusal, keep the documents and change the plan.
