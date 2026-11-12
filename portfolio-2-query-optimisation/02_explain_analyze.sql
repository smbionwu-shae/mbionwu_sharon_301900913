-- 02_explain_analyze.sql
-- Demonstrates the effect of the Portfolio-2 selective indexes on the four
-- selective queries from 01_queries.sql. The script:
--   1. Drops the P2 selective indexes.
--   2. Runs EXPLAIN (ANALYZE, BUFFERS) for the four selective queries.
--   3. Re-creates the indexes.
--   4. Runs EXPLAIN (ANALYZE, BUFFERS) again for the same four queries.
--   5. Runs EXPLAIN (ANALYZE, BUFFERS) on one full aggregate to show that
--      Seq Scan stays the best plan there regardless of indexes.
--
-- Run with:  psql -d ststephen -v ON_ERROR_STOP=1 -f 02_explain_analyze.sql

\set ON_ERROR_STOP on
\timing on
SET timezone TO 'Africa/Lagos';

\echo '=============================================================='
\echo 'PHASE 1 — DROPPING P2 selective indexes'
\echo '=============================================================='

DROP INDEX IF EXISTS idx_result_student_graded;
DROP INDEX IF EXISTS idx_registration_recent;
DROP INDEX IF EXISTS idx_student_department;
DROP INDEX IF EXISTS idx_offering_lecturer;
-- Keep idx_registration_student (used by the result trigger) so writes
-- still work; we are only testing read plans here.

\echo '=============================================================='
\echo 'PHASE 2 — EXPLAIN (ANALYZE, BUFFERS) WITHOUT indexes'
\echo '=============================================================='

\echo '--- Q1 (one student transcript) without idx_result_student_graded ---'
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT c.course_code, e.exam_type, r.score, r.graded_at
FROM student s
JOIN result          r ON r.student_id  = s.student_id
JOIN exam            e ON e.exam_id     = r.exam_id
JOIN course_offering o ON o.offering_id = e.offering_id
JOIN course          c ON c.course_id   = o.course_id
WHERE s.student_id = 1
ORDER BY r.graded_at DESC
LIMIT 20;

\echo '--- Q2 (one department students) without idx_student_department ---'
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT s.matric_no, s.full_name, s.status
FROM student s
WHERE s.department_id = 1
ORDER BY s.matric_no
LIMIT 30;

\echo '--- Q3 (one lecturer offerings) without idx_offering_lecturer ---'
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT c.course_code, c.course_title, o.semester, o.academic_year, o.capacity
FROM lecturer l
JOIN course_offering o ON o.lecturer_id = l.lecturer_id
JOIN course           c ON c.course_id  = o.course_id
WHERE l.lecturer_id = 1
ORDER BY o.academic_year DESC, o.semester, c.course_code;

\echo '--- Q4 (last 30 days registrations) without idx_registration_recent ---'
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT s.matric_no, c.course_code, r.registered_at
FROM registration r
JOIN student         s ON s.student_id  = r.student_id
JOIN course_offering o ON o.offering_id = r.offering_id
JOIN course          c ON c.course_id   = o.course_id
WHERE r.registered_at >= now() - make_interval(0, 0, 0, 30, 0, 0, 0)
  AND r.status = 'ACTIVE'
ORDER BY r.registered_at DESC
LIMIT 30;

\echo '=============================================================='
\echo 'PHASE 3 — RE-CREATING P2 selective indexes'
\echo '=============================================================='

CREATE INDEX IF NOT EXISTS idx_result_student_graded
    ON result (student_id, graded_at DESC);

CREATE INDEX IF NOT EXISTS idx_registration_recent
    ON registration (registered_at DESC)
    WHERE status = 'ACTIVE';

CREATE INDEX IF NOT EXISTS idx_student_department
    ON student (department_id);

CREATE INDEX IF NOT EXISTS idx_offering_lecturer
    ON course_offering (lecturer_id);

ANALYZE result;
ANALYZE registration;
ANALYZE student;
ANALYZE course_offering;

\echo '=============================================================='
\echo 'PHASE 4 — EXPLAIN (ANALYZE, BUFFERS) WITH indexes'
\echo '=============================================================='

\echo '--- Q1 (one student transcript) with idx_result_student_graded ---'
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT c.course_code, e.exam_type, r.score, r.graded_at
FROM student s
JOIN result          r ON r.student_id  = s.student_id
JOIN exam            e ON e.exam_id     = r.exam_id
JOIN course_offering o ON o.offering_id = e.offering_id
JOIN course          c ON c.course_id   = o.course_id
WHERE s.student_id = 1
ORDER BY r.graded_at DESC
LIMIT 20;

\echo '--- Q2 (one department students) with idx_student_department ---'
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT s.matric_no, s.full_name, s.status
FROM student s
WHERE s.department_id = 1
ORDER BY s.matric_no
LIMIT 30;

\echo '--- Q3 (one lecturer offerings) with idx_offering_lecturer ---'
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT c.course_code, c.course_title, o.semester, o.academic_year, o.capacity
FROM lecturer l
JOIN course_offering o ON o.lecturer_id = l.lecturer_id
JOIN course           c ON c.course_id  = o.course_id
WHERE l.lecturer_id = 1
ORDER BY o.academic_year DESC, o.semester, c.course_code;

\echo '--- Q4 (last 30 days registrations) with idx_registration_recent ---'
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT s.matric_no, c.course_code, r.registered_at
FROM registration r
JOIN student         s ON s.student_id  = r.student_id
JOIN course_offering o ON o.offering_id = r.offering_id
JOIN course          c ON c.course_id   = o.course_id
WHERE r.registered_at >= now() - make_interval(0, 0, 0, 30, 0, 0, 0)
  AND r.status = 'ACTIVE'
ORDER BY r.registered_at DESC
LIMIT 30;

\echo '=============================================================='
\echo 'PHASE 5 — Aggregate query (Seq Scan stays optimal)'
\echo '=============================================================='

\echo '--- Q5 (avg FINAL score per course) — expect Seq Scan regardless ---'
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT
    c.course_code,
    count(*) AS attempts,
    round(avg(r.score)::numeric, 2) AS avg_score
FROM result r
JOIN exam            e ON e.exam_id     = r.exam_id
JOIN course_offering o ON o.offering_id = e.offering_id
JOIN course          c ON c.course_id   = o.course_id
WHERE e.exam_type = 'FINAL'
GROUP BY c.course_code
ORDER BY avg_score DESC NULLS LAST
LIMIT 30;

\echo '02_explain_analyze.sql finished'
