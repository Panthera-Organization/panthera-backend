# Attack catalog

Write a pgTAP test for every attack that applies to a table. Use `set local role authenticated` plus `request.jwt.claims` to act as a user (see the `add-table` pgTAP template).

| Attack | Example | Expected |
|---|---|---|
| Cross-tenant read | Teacher of company A selects company B's rows | 0 rows |
| Cross-tenant move | Update a row's `company_id` to another company | `42501` |
| Role escalation | Student sets own `assignments.status` to `reviewed` | Failure |
| Writing another role's table | Student inserts into `answer_reviews` | `42501` |
| Self-promotion | User inserts or updates own `memberships.role` to `owner` | Failure |
| Impersonation | Insert with `created_by` / `student_id` set to another user | `42501` |
| Locked state | Student edits an answer after the assignment is `submitted` | Failure |
| Anonymous access | `set local role anon`, then select each table | 0 rows |
| Function abuse | Call each security definer function with another user's ids | Failure |
| Invite abuse | Redeem an expired, revoked, or fully used invite; redeem twice | Failure |
| Storage path escape | Upload or read an object under another company's path prefix | Failure |
