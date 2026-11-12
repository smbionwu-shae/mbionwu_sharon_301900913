# Portfolio 2 — Query Optimisation

**Student:** Sharon Chibuzor Mbionwu — 2026/A/MIT/0060 — MIT, Miva Open University

## Files

| File | Purpose |
| --- | --- |
| `01_queries.sql` | 8 queries: 4 selective (one student's transcript, one department's students, one lecturer's offerings, last 30 days of registrations) and 4 full-table aggregates (average score per course, pass rate per department, fees owed per student derived from rows, top-10 lecturers by load). |
| `02_explain_analyze.sql` | Drops the four P2 selective indexes, runs `EXPLAIN (ANALYZE, BUFFERS)` on the four selective queries, re-creates the indexes, runs them again, then runs `EXPLAIN (ANALYZE, BUFFERS)` on one aggregate query (Q5) to show that the planner keeps a Seq Scan there. |

## Honest expectation

The selective queries (Q1–Q4) are expected to switch from a `Seq Scan` to
an `Index Scan` / `Index Only Scan` once the P2 indexes are recreated,
and their execution time should drop accordingly.

The aggregate queries (Q5–Q8) **are not expected to get faster**. They
scan most or all of `result`, `registration` or `fee_payment`, so the
planner correctly keeps a `Seq Scan` and a Hash Aggregate. The README
does **not** claim "every query gets faster" — Q5 is included in
`02_explain_analyze.sql` precisely so the student can see the Seq Scan
is still there with the indexes in place.

## Sample EXPLAIN output

```text
[paste real output here]
```

## Notes on SQL style

- `make_interval(0, 0, 0, 30, 0, 0, 0)` is used instead of `interval '30 days'`
  to avoid the `round(interval)` anti-pattern and to satisfy the "cast
  `make_interval` args to `int`" rule.
- `now() - make_interval(...)` is used for "last 30 days"; `CURRENT_DATE`
  is only used in triggers, never inside `CHECK` constraints.
