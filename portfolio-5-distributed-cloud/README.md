# Portfolio 5 — Distributed / Cloud

**Student:** Sharon Chibuzor Mbionwu — 2026/A/MIT/0060 — MIT, Miva Open University

## Files

| File | Purpose |
| --- | --- |
| `01_partitioning.sql` | Monthly RANGE partitioning of the `registration` table. Creates a partitioned parent `registration_p` whose PRIMARY KEY and partial UNIQUE index both include the partition key (`registered_at`) — a PG16 requirement. A `DO` loop creates one monthly partition for every month present in the source data plus next month, plus a `DEFAULT` partition. Copies the rows from `registration` into `registration_p`, prints rows-per-partition, and runs one `EXPLAIN (ANALYZE, BUFFERS)` on a one-month range query to demonstrate partition pruning. No `EXCLUDE USING` constraint is attempted — PG16 does not allow exclusion constraints on a partitioned parent. |
| `02_replica_setup.sh` | Builds a streaming replica of `ststephen` on port 55432 with `pg_basebackup` over the Unix socket (no TCP, no passwords). |
| `03_replica_tests.sql` | One script that switches between primary (5432) and replica (55432): who is who, a write rejected on the replica, a row inserted on the primary arriving on the replica, replication lag and `pg_stat_replication`. |
| `cloud_design.md` | Managed-database design for the St. Stephen workload: multi-AZ primary, in-region and cross-region read replicas, daily snapshots + PITR, sync vs async replication trade-offs, and Nigerian data-protection notes (NDPA 2023 and CBN rules). Cloud regions are cited only where they actually exist (AWS `af-south-1` Cape Town; Azure `South Africa North` Johannesburg and `South Africa West` Cape Town; GCP `africa-south1` Johannesburg) — no invented Nigeria-based regions. NDPA 2023 references the Act and its obligations without citing specific section numbers. |

## Run

```
psql -d ststephen -v ON_ERROR_STOP=1 -f 01_partitioning.sql
bash 02_replica_setup.sh
psql -d ststephen -f 03_replica_tests.sql
```

Run after the bulk data has been loaded (Portfolio 1's `04_bulk_data.sql`),
otherwise the `DO` loop has no source rows to derive the partition range
from and the script aborts with a clear error message.

## Expected output

```text
[paste real output here]
```

The `EXPLAIN (ANALYZE, BUFFERS)` plan for the one-month range query
should show only **one** partition being scanned, with `Subplans
Removed: N` where N is the count of other monthly partitions that
were pruned by the planner.
