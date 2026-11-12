# Portfolio 1 — Database Design

**Student:** Sharon Chibuzor Mbionwu — 2026/A/MIT/0060 — MIT, Miva Open University

## Files

| File | Purpose |
| --- | --- |
| `01_schema.sql` | Creates 10 tables in 3NF (faculty, department, lecturer, student, course, course_offering, registration, exam, result, fee_payment) with PK, FK, UNIQUE and CHECK constraints; declares the partial UNIQUE index that allows only one ACTIVE registration per (student, offering); installs four BEFORE triggers (capacity, result-registered, lecturer-clash, no-past-exam-date). Sets the database time zone to `Africa/Lagos`. |
| `02_indexes.sql` | Indexes every foreign key that a trigger or a report uses, plus the selective secondary indexes used by Portfolio 2. Re-declares the partial UNIQUE index with `IF NOT EXISTS` so it is safe to re-run. |
| `03_seed_data.sql` | Small realistic Nigerian seed: 4 faculties, 8 departments, 12 lecturers, 20 students, 12 courses, 8 course offerings, exams, registrations, results and fee payments in Naira. Idempotent (`ON CONFLICT DO NOTHING`). |
| `04_bulk_data.sql` | Adds 1,000 students, 96 courses, 500 offerings, ~60,000 registrations, ~30,000 results and ~2,000 fee payments using `generate_series` directly inside SQL. Dates are relative to `CURRENT_DATE` (history plus next 14 days, with some future registrations). Every insert succeeds by design. Does not truncate rows that later demos use. |
| `05_constraint_tests.sql` | 10 tests + 1 control. Each test builds its own data inside `BEGIN … ROLLBACK`, attempts the operation that must fail, catches the exception and prints `PASS (SQLSTATE …)` or `FAIL`. The control test inserts a valid registration and must succeed. |

## Run order

```
psql -d ststephen -v ON_ERROR_STOP=1 -f 01_schema.sql
psql -d ststephen -v ON_ERROR_STOP=1 -f 02_indexes.sql
psql -d ststephen -v ON_ERROR_STOP=1 -f 03_seed_data.sql
psql -d ststephen -v ON_ERROR_STOP=1 -f 04_bulk_data.sql
psql -d ststephen -v ON_ERROR_STOP=1 -f 05_constraint_tests.sql
```

## Concurrency note

The `enforce_capacity` trigger enforces capacity in a single session but
races under concurrent `READ COMMITTED` transactions (two students each
see `count < capacity` and both insert). This is intentional: Portfolio 3
demonstrates the bug and the fix (PostgreSQL advisory lock).

## Row counts after `04_bulk_data.sql`

```text
[paste real output here]
```

## `05_constraint_tests.sql` output

```text
[paste real output here]
```
