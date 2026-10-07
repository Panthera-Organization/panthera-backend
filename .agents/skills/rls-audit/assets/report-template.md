# RLS audit — <date>

## Summary
<number of findings by severity, one-line verdict>

## Findings

### [Critical|High|Medium|Low] <title>
- **Where:** <table / policy / function / file:line>
- **What can happen:** <concrete scenario, e.g. "a student of company A can read company B's homework">
- **Proof:** <failing test name>
- **Proposed fix:**
  ```sql
  <SQL>
  ```

## Verified (attacks blocked)
<list of passing attack tests>

## Matrix gaps
<operations the matrix doesn't define, or rules that need a human decision>

---

Severity guide:
- **Critical:** cross-tenant access, or children's data reachable by the wrong people.
- **High:** role escalation within a tenant.
- **Medium:** missing hardening (`search_path`, grants) without a demonstrated exploit.
- **Low:** style issues that make policies hard to reason about.
