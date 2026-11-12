-- 01_queries.sql
-- Eight reporting queries for St. Stephen USMS.
--   4 selective:  one student's transcript, one department's students,
--                 one lecturer's offerings, registrations in the last 30 days.
--   4 aggregates: average score per course, pass rate per department,
--                 fees owed per student (derived), top-10 lecturers by load.
--
-- Run with:  psql -d ststephen -v ON_ERROR_STOP=1 -f 01_queries.sql

\set ON_ERROR_STOP on
SET timezone TO 'Africa/Lagos';

\echo '=== Q1 — One student: full transcript (student_id = 1) ==='
-- Selective: uses idx_result_student_graded (student_id, graded_at DESC)
-- and idx_registration_student.
SELECT
    s.matric_no,
    s.full_name,
    c.course_code,
    c.course_title,
    e.exam_type,
    r.score,
    r.graded_at
FROM student s
JOIN result          r ON r.student_id = s.student_id
JOIN exam            e ON e.exam_id    = r.exam_id
JOIN course_offering o ON o.offering_id = e.offering_id
JOIN course          c ON c.course_id  = o.course_id
WHERE s.student_id = 1
ORDER BY r.graded_at DESC
LIMIT 20;

\echo '=== Q2 — One department: all students with status (department_id = 1, Computer Science) ==='
-- Selective: uses idx_student_department.
SELECT
    s.matric_no,
    s.full_name,
    s.gender,
    s.email,
    s.enrolled_on,
    s.status,
    (SELECT count(*)
       FROM registration rg
      WHERE rg.student_id = s.student_id AND rg.status = 'ACTIVE') AS active_regs
FROM student s
WHERE s.department_id = 1
ORDER BY s.matric_no
LIMIT 30;

\echo '=== Q3 — One lecturer: all offerings taught (lecturer_id = 1) ==='
-- Selective: uses idx_offering_lecturer.
SELECT
    l.staff_no,
    l.full_name AS lecturer,
    c.course_code,
    c.course_title,
    o.semester,
    o.academic_year,
    o.capacity,
    o.slot_day,
    o.start_time,
    o.end_time,
    (SELECT count(*)
       FROM registration r
      WHERE r.offering_id = o.offering_id AND r.status = 'ACTIVE') AS active_count
FROM lecturer l
JOIN course_offering o ON o.lecturer_id = l.lecturer_id
JOIN course           c ON c.course_id  = o.course_id
WHERE l.lecturer_id = 1
ORDER BY o.academic_year DESC, o.semester, c.course_code;

\echo '=== Q4 — Registrations in the last 30 days ==='
-- Selective: uses idx_registration_recent (registered_at DESC) WHERE status='ACTIVE'.
SELECT
    s.matric_no,
    s.full_name,
    c.course_code,
    c.course_title,
    r.registered_at
FROM registration r
JOIN student         s ON s.student_id  = r.student_id
JOIN course_offering o ON o.offering_id = r.offering_id
JOIN course          c ON c.course_id   = o.course_id
WHERE r.registered_at >= now() - make_interval(0, 0, 0, 30, 0, 0, 0)
  AND r.status = 'ACTIVE'
ORDER BY r.registered_at DESC
LIMIT 30;

\echo '=== Q5 — Aggregate: average FINAL exam score per course ==='
-- Full aggregate over result ⨝ exam ⨝ course_offering ⨝ course.
-- Expect a Seq Scan here — see README.
SELECT
    c.course_code,
    c.course_title,
    count(*)                                    AS attempts,
    round(avg(r.score)::numeric, 2)             AS avg_score,
    round(stddev_pop(r.score)::numeric, 2)      AS stddev_score
FROM result r
JOIN exam            e ON e.exam_id     = r.exam_id
JOIN course_offering o ON o.offering_id = e.offering_id
JOIN course          c ON c.course_id   = o.course_id
WHERE e.exam_type = 'FINAL'
GROUP BY c.course_code, c.course_title
ORDER BY avg_score DESC NULLS LAST
LIMIT 30;

\echo '=== Q6 — Aggregate: pass rate per department (FINAL exam, pass mark 40) ==='
-- Full aggregate over result ⨝ exam ⨝ offering ⨝ course ⨝ department.
-- Expect a Seq Scan here — see README.
SELECT
    d.department_code,
    d.department_name,
    count(*) AS attempts,
    count(*) FILTER (WHERE r.score >= 40) AS passed,
    round(100.0 * count(*) FILTER (WHERE r.score >= 40) / nullif(count(*), 0), 2)
        AS pass_rate_pct
FROM result r
JOIN exam            e ON e.exam_id     = r.exam_id
JOIN course_offering o ON o.offering_id = e.offering_id
JOIN course          c ON c.course_id   = o.course_id
JOIN department      d ON d.department_id = c.department_id
WHERE e.exam_type = 'FINAL'
GROUP BY d.department_code, d.department_name
ORDER BY pass_rate_pct DESC NULLS LAST;

\echo '=== Q7 — Aggregate: fees owed per student (derived) ==='
-- Tuition owed = active registrations × credit units × per-unit rate,
-- minus sum of fee_payments. Per-unit rate is NGN 5,000.
-- Totals are DERIVED from registration + course + payment rows, not typed in.
-- Full aggregate — expect a Seq Scan.
WITH owed AS (
    SELECT
        s.student_id,
        s.matric_no,
        s.full_name,
        d.department_name,
        sum(c.credit_units * 5000)::numeric(12,2) AS tuition_naira
    FROM student s
    JOIN registration  r ON r.student_id  = s.student_id
    JOIN course_offering o ON o.offering_id = r.offering_id
    JOIN course        c ON c.course_id   = o.course_id
    JOIN department    d ON d.department_id = s.department_id
    WHERE r.status = 'ACTIVE'
    GROUP BY s.student_id, s.matric_no, s.full_name, d.department_name
),
paid AS (
    SELECT student_id, sum(amount_naira)::numeric(12,2) AS paid_naira
    FROM fee_payment
    GROUP BY student_id
)
SELECT
    o.matric_no,
    o.full_name,
    o.department_name,
    o.tuition_naira,
    COALESCE(p.paid_naira, 0)                                AS paid_naira,
    (o.tuition_naira - COALESCE(p.paid_naira, 0))::numeric(12,2) AS balance_naira
FROM owed o
LEFT JOIN paid p ON p.student_id = o.student_id
ORDER BY balance_naira DESC NULLS LAST
LIMIT 20;

\echo '=== Q8 — Aggregate: top-10 lecturers by active registrations taught ==='
-- Full aggregate over registration ⨝ offering ⨝ lecturer ⨝ department.
-- Expect a Seq Scan here — see README.
SELECT
    l.staff_no,
    l.full_name AS lecturer,
    d.department_name,
    count(*) AS active_registrations,
    count(DISTINCT o.offering_id) AS offerings_taught
FROM lecturer l
JOIN course_offering o ON o.lecturer_id = l.lecturer_id
JOIN registration    r ON r.offering_id = o.offering_id AND r.status = 'ACTIVE'
JOIN department      d ON d.department_id = l.department_id
GROUP BY l.staff_no, l.full_name, d.department_name
ORDER BY active_registrations DESC
LIMIT 10;
