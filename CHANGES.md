# CHANGES.md - Sharon Chibuzor Mbionwu, 2026/A/MIT/0060 (database: ststephen)

Drafted by Z.ai. Tested in a Codespaces-like setup (non-root user, Unix socket, no passwords) and fixed by Claude. Run by the student.
Every "tested result" below comes from a real run here. Student-side evidence must come from the student's own run (`my_results.txt`).

| # | File | Problem when run | Fix | Tested result |
|---|------|------------------|-----|---------------|
| 1 | P1 `01_schema.sql` | `matric_no` and `staff_no` were VARCHAR(15), but values like `SSU/CSC/2022/001` are 16 characters, so the seed insert failed ("value too long") | Widened both to VARCHAR(20) | Seed loads: 20 students, 12 lecturers |
| 2 | P1 `04_bulk_data.sql` | The bulk offerings put lecturers 1 to 6 in slots that overlapped the seed offerings, so the clash trigger stopped the whole script | Bulk offerings now use 1-hour slots from 12:00 to 17:00, after the 08:00-12:00 seed slots | 59,165 registrations, 1,020 students, 508 offerings |
| 3 | P1 `05_constraint_tests.sql` | Test 2 expected FK error 23503 but the capacity trigger fired first and raised P0001 | Test 2 now checks the FK on `exam.offering_id` | 10 tests PASS plus the control test |
| 4 | P3 `01_transactions.sql` | `SAVEPOINT` and `ROLLBACK TO` inside a DO block are invalid SQL (syntax error) | Removed them (the BEGIN/EXCEPTION block is the implicit savepoint) and noted this in a comment | Runs; the second insert is refused and the first stays |
| 5 | P3 `01_transactions.sql` | Not re-runnable: A/B picked every TXNC01 offering and the offering inserts tripped the clash trigger on a second run | Restricted A/B to the FIRST offering, guarded the offering inserts, and cleared old demo registrations at the top | Ran twice in a row with no errors |
| 6 | P3 `race_demos.py` | Each demo offering used the same weekday and time for one lecturer, so the clash trigger stopped Part 1 | Each offering gets its own weekday | Parts 1 to 6 all run |
| 7 | P3 `race_demos.py` | Part 3 (advisory lock) hung forever: the barrier sat after the lock, which the second session never reached | Barrier moved before the lock | Part 3: one row committed, the other refused (trigger fires after the lock) |
| 8 | P3 `race_demos.py` | Part 6b (fixed lock order) hung for the same barrier reason | Barrier size 1 for 6b | 6a: deadlock 40P01, 6b: both commit |
| 9 | P3 `race_demos.py` | Not re-runnable after a failed run | `cleanup()` also runs at the start | Re-run is clean |
| 10 | P4 `01_setup.js` | `required: []` is rejected by MongoDB ($jsonSchema), so the collections were never created | Removed the empty array | Collections created with validators |
| 11 | P4 `01_setup.js` | `tojson` does not exist in mongosh scripts | Used `JSON.stringify` | Setup prints OK |
| 12 | P4 `03_bulk_and_index_demo.js` | The demo query (student 500, FINAL) matched no documents, so BEFORE and AFTER showed 0 rows; the dropIndex message was noisy | Target taken from a real document; silent try/catch on the drop | COLLSCAN 40,000 docs examined, IXSCAN 39 docs examined |
| 13 | P4 `02_data_and_queries.js` | No proof that the validator rejects bad data | Added 2 invalid documents that must be rejected | Both rejected (code 121) |
| 14 | P5 | No replica at all (the CA needs a partition plus a replica) | Added `02_replica_setup.sh` (pg_basebackup over the Unix socket, minimal conf, hba and ident copied, chmod 700, port 55432) and `03_replica_tests.sql` (one script that switches servers) | Replica streaming; write rejected on the replica; row arrived; lag shown |
| 15 | Root | `setup.sh`, `runall.sh` and `collect_results.sh` missing | Written new: `runall.sh` runs P1 to P5, commits after each, ends with `collect_results.sh` writing `my_results.txt`; setup uses `sudo runuser -u postgres`, a pip fallback chain, and sets the database time zone | Full run as a non-root user, exit 0 |

## Not changed / notes for the defence
- P2: the selective queries (Q1 to Q4) show Seq Scan to index plans; the aggregate Q5 keeps its Seq Scan on purpose.
- P3 Part 1 shows that the capacity trigger alone does NOT stop the race under READ COMMITTED (two rows land); Part 3 (advisory lock) is the fix.
- The reference FIXED zip was not attached, so the runner and replica scripts were written new using the standard patterns (they were not copied from another student).
- No other student's name, matric or database name appears in the project.
