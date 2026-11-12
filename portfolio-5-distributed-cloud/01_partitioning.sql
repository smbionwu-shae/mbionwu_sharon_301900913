-- 01_partitioning.sql
-- Monthly RANGE partitioning of the high-volume `registration` table for
-- cloud-scale reporting. The partition key is `registered_at` (TIMESTAMPTZ).
--
-- What this script does:
--   1. Creates a new partitioned table `registration_p` whose PRIMARY KEY
--      includes the partition key (PG16 requires unique keys on a
--      partitioned parent to include the partition key).
--   2. Creates a partial UNIQUE index on (student_id, offering_id,
--      registered_at) WHERE status='ACTIVE' — the partition key is added
--      so the index is allowed on the partitioned parent.
--   3. Runs a DO loop that creates one monthly partition for EVERY month
--      present in the source `registration` table, plus next month, plus
--      a DEFAULT partition.
--   4. Copies all rows from `registration` into `registration_p`.
--   5. Prints rows per partition.
--   6. Runs EXPLAIN (ANALYZE, BUFFERS) on a one-month range query to show
--      partition pruning.
--
-- PG16 does NOT allow exclusion constraints (EXCLUDE USING) on a
-- partitioned parent — we do not attempt one.
--
-- Run with:  psql -d ststephen -v ON_ERROR_STOP=1 -f 01_partitioning.sql

\set ON_ERROR_STOP on
SET timezone TO 'Africa/Lagos';

-- =====================================================================
-- 1. Drop the partitioned table from any previous run (cascades to all
--    partitions and indexes).
-- =====================================================================
DROP TABLE IF EXISTS registration_p CASCADE;

-- =====================================================================
-- 2. Create the partitioned parent. The PRIMARY KEY is composite and
--    includes the partition key (registered_at) — this is required by
--    PostgreSQL for partitioned tables.
-- =====================================================================
CREATE TABLE registration_p (
    registration_id BIGINT          NOT NULL,
    student_id      INTEGER         NOT NULL,
    offering_id     INTEGER         NOT NULL,
    registered_at   TIMESTAMPTZ     NOT NULL,
    status          VARCHAR(10)     NOT NULL CHECK (status IN ('ACTIVE','DROPPED','COMPLETED')),
    PRIMARY KEY (registration_id, registered_at)
) PARTITION BY RANGE (registered_at);

-- =====================================================================
-- 3. Partial UNIQUE index that includes the partition key. The semantics
--    are slightly weaker than on the non-partitioned table (two ACTIVE
--    rows for the same (student, offering) with different registered_at
--    are now allowed) — this is the price of putting a unique constraint
--    on a partitioned table in PostgreSQL.
-- =====================================================================
CREATE UNIQUE INDEX uq_one_active_reg_per_student_offering_p
    ON registration_p (student_id, offering_id, registered_at)
    WHERE status = 'ACTIVE';

-- =====================================================================
-- 4. DO loop — create one monthly partition for every month that appears
--    in the source `registration` table, plus next month, plus a DEFAULT
--    partition. PG16 allows CREATE TABLE PARTITION OF inside EXECUTE
--    within a DO block.
-- =====================================================================
DO $$
DECLARE
    v_min     DATE;
    v_max     DATE;
    v_cur     DATE;
    v_next    DATE;
    v_part    TEXT;
BEGIN
    SELECT date_trunc('month', min(registered_at))::date,
           date_trunc('month', max(registered_at))::date
      INTO v_min, v_max
      FROM registration;

    IF v_min IS NULL OR v_max IS NULL THEN
        RAISE EXCEPTION 'No rows in registration — run 04_bulk_data.sql first';
    END IF;

    -- Add one month to v_max so the loop covers "next month" too.
    v_max := (date_trunc('month', v_max) + interval '1 month')::date;

    RAISE NOTICE 'Partition range: % to %', v_min, v_max;

    v_cur := v_min;
    WHILE v_cur <= v_max LOOP
        v_next := (v_cur + interval '1 month')::date;
        v_part := 'registration_p_' || to_char(v_cur, 'YYYY_MM');
        EXECUTE format(
            'CREATE TABLE IF NOT EXISTS %I PARTITION OF registration_p
                FOR VALUES FROM (%L) TO (%L)',
            v_part, v_cur, v_next
        );
        v_cur := v_next;
    END LOOP;

    -- DEFAULT partition catches anything outside the monthly ranges
    -- (e.g. a row whose registered_at is before v_min or after v_max+1mo).
    EXECUTE 'CREATE TABLE IF NOT EXISTS registration_p_default
                PARTITION OF registration_p DEFAULT';

    RAISE NOTICE 'Created monthly partitions plus DEFAULT partition';
END $$;

-- =====================================================================
-- 5. Copy all rows from the original registration table. The capacity
--    trigger does not fire on registration_p (it has no trigger), so the
--    copy is a straight INSERT … SELECT.
-- =====================================================================
INSERT INTO registration_p (registration_id, student_id, offering_id,
                            registered_at, status)
SELECT registration_id, student_id, offering_id, registered_at, status
FROM registration
ON CONFLICT DO NOTHING;

-- =====================================================================
-- 6. Sanity report — rows per partition.
-- =====================================================================
\echo '=== Rows per partition ==='
SELECT
    tableoid::regclass::text AS partition_name,
    count(*)                 AS rows
FROM registration_p
GROUP BY tableoid::regclass
ORDER BY partition_name;

-- =====================================================================
-- 7. EXPLAIN (ANALYZE, BUFFERS) for a one-month range query.
--    The plan should show only ONE partition being scanned (Subplans
--    Removed: N — every other monthly partition is pruned).
-- =====================================================================
\echo '=== EXPLAIN ANALYZE — one-month range query (last month) ==='
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT student_id, offering_id, registered_at, status
FROM registration_p
WHERE registered_at >= date_trunc('month', now() - interval '1 month')::timestamptz
  AND registered_at <  date_trunc('month', now())::timestamptz
ORDER BY registered_at
LIMIT 50;

\echo '01_partitioning.sql finished'
