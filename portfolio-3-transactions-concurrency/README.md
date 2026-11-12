# Portfolio 3 — Transactions and Concurrency

**Student:** Sharon Chibuzor Mbionwu — 2026/A/MIT/0060 — MIT, Miva Open University

## Files

| File | Purpose |
| --- | --- |
| `01_transactions.sql` | Three transaction scenarios: a committed registration, a rolled-back registration, and a SAVEPOINT recovery (a savepoint is rolled back to after a deliberate failure, while the outer transaction still commits its first valid insert). |
| `race_demos.py` | Six labelled concurrency demos using `psycopg2` and two real sessions in Python threads. Creates its own demo rows (faculty `RDF`, department `RDFT`, lecturer, course `RDFC01`, two students, several offerings, helper tables) and deletes them at the end. |

## Run

```
psql -d ststephen -v ON_ERROR_STOP=1 -f 01_transactions.sql
python3 race_demos.py
```

`race_demos.py` needs `psycopg2-binary` (`pip install psycopg2-binary`). It
connects over the Unix socket with `dbname=ststephen` (no password, no
TCP) — the GitHub Codespaces default.

## What `race_demos.py` demonstrates

| Part | Scenario | Expected SQLSTATE |
| --- | --- | --- |
| 1. The bug | Two students race for the last place in a capacity-1 offering. The capacity trigger sees `count=0` in both `READ COMMITTED` transactions, so both INSERTs succeed; capacity is violated. | none — both commit |
| 2. Constraint fix | A `race_demo_capacity(offering_id, capacity, active_count)` table with `CHECK (active_count <= capacity)`. The first `UPDATE` of the counter row blocks the second transaction; the second transaction's `UPDATE` then trips the CHECK. | `23514` (check_violation) |
| 3. Advisory lock fix | `SELECT pg_advisory_xact_lock(offering_id)` at the start of each transaction. The second transaction blocks until the first commits, then sees the now-full offering and the trigger fires. | `23514` (check_violation) |
| 4. SERIALIZABLE | Both transactions run at SERIALIZABLE isolation. PostgreSQL's SSI detects the read/write conflict and aborts one at COMMIT. | `40001` (serialization_failure) |
| 5. READ COMMITTED vs REPEATABLE READ | A reader transaction reads a row, a writer updates and commits, the reader reads again. READ COMMITTED sees the new value; REPEATABLE READ keeps the snapshot value. | (none — pure snapshot demo) |
| 6. Deadlock + fixed version | Two transactions update rows in opposite orders; PostgreSQL detects a deadlock. Then both transactions update in the same order and both commit cleanly. | `40P01` (deadlock_detected) in 6a; both commit in 6b |

The script uses a `threading.Barrier` to start the two workers' critical
section at the same time; there are no `pg_sleep` tricks that need
hand-pasting and no `psql <<SQL` two-terminal demos.

## Sample output

```text
[paste real output here]
```
