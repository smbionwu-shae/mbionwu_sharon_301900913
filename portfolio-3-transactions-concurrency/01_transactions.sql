-- 01_transactions.sql
-- Three transaction scenarios for St. Stephen USMS:
--   A. A committed registration transaction.
--   B. A rolled-back registration transaction (the row never lands).
--   C. A SAVEPOINT recovery: an outer transaction does two inserts, the
--      second one fails inside a savepoint, the savepoint is rolled back
--      to and the first insert is committed.
--
-- Run with:  psql -d ststephen -v ON_ERROR_STOP=1 -f 01_transactions.sql

\set ON_ERROR_STOP on
SET timezone TO 'Africa/Lagos';

-- Re-runnable: remove registrations left by an earlier run of this file.
DELETE FROM registration WHERE student_id IN (SELECT student_id FROM student WHERE matric_no LIKE 'TXN/S/%');

-- =====================================================================
-- Demo scaffolding: a dedicated student and offering for transaction
-- experiments, so they don't disturb bulk data. Idempotent.
-- =====================================================================
INSERT INTO faculty (faculty_code, faculty_name, dean_name)
VALUES ('TXN', 'Transaction Demo Faculty', 'Prof. Txn Demo')
ON CONFLICT (faculty_code) DO NOTHING;

INSERT INTO department (department_code, department_name, faculty_id, hod_name)
VALUES ('TXND', 'Transaction Demo Dept',
        (SELECT faculty_id FROM faculty WHERE faculty_code='TXN'),
        'Dr. Txn HOD')
ON CONFLICT (department_code) DO NOTHING;

INSERT INTO lecturer (staff_no, full_name, gender, department_id, email, hired_on)
VALUES ('TXN/L001', 'Dr. Transaction Lecturer', 'M',
        (SELECT department_id FROM department WHERE department_code='TXND'),
        'txn.l001@ststephen.edu.ng', CURRENT_DATE)
ON CONFLICT (staff_no) DO NOTHING;

INSERT INTO course (course_code, course_title, credit_units, department_id, level)
VALUES ('TXNC01', 'Transaction Demo Course', 3,
        (SELECT department_id FROM department WHERE department_code='TXND'), 300)
ON CONFLICT (course_code) DO NOTHING;

INSERT INTO course_offering
    (course_id, lecturer_id, semester, academic_year, capacity,
     offering_date, slot_day, start_time, end_time)
SELECT c.course_id, l.lecturer_id, 'FIRST', '2025/2026', 50,
       CURRENT_DATE + 7, 3, '14:00', '16:00'
FROM course c, lecturer l
WHERE c.course_code='TXNC01' AND l.staff_no='TXN/L001'
  AND NOT EXISTS (SELECT 1 FROM course_offering x WHERE x.course_id=c.course_id AND x.semester='FIRST' AND x.academic_year='2025/2026')
ON CONFLICT (course_id, semester, academic_year) DO NOTHING;

-- Two dedicated students
INSERT INTO student (matric_no, full_name, gender, department_id, email, enrolled_on, status)
VALUES
    ('TXN/S/001', 'Adaeze Transaction',   'F',
     (SELECT department_id FROM department WHERE department_code='TXND'),
     'txn.s.001@ststephen.edu.ng', CURRENT_DATE, 'ACTIVE'),
    ('TXN/S/002', 'Bola Transaction',     'M',
     (SELECT department_id FROM department WHERE department_code='TXND'),
     'txn.s.002@ststephen.edu.ng', CURRENT_DATE, 'ACTIVE')
ON CONFLICT (matric_no) DO NOTHING;

-- =====================================================================
-- A. COMMITTED registration transaction
-- =====================================================================
\echo '=== A. COMMITTED transaction ==='

BEGIN;
INSERT INTO registration (student_id, offering_id, status)
SELECT s.student_id, o.offering_id, 'ACTIVE'
FROM student s, course_offering o
WHERE s.matric_no='TXN/S/001'
  AND o.semester = 'FIRST' AND o.course_id = (SELECT course_id FROM course WHERE course_code='TXNC01');
COMMIT;

SELECT 'A: committed registration exists = '
    || count(*)::text AS message
FROM registration r
JOIN student s ON s.student_id = r.student_id
JOIN course_offering o ON o.offering_id = r.offering_id
WHERE s.matric_no='TXN/S/001'
  AND o.semester = 'FIRST' AND o.course_id = (SELECT course_id FROM course WHERE course_code='TXNC01');

-- =====================================================================
-- B. ROLLED-BACK registration transaction
-- =====================================================================
\echo '=== B. ROLLED-BACK transaction ==='

SELECT 'B: rows before = ' || count(*)::text AS message
FROM registration r
JOIN student s ON s.student_id = r.student_id
JOIN course_offering o ON o.offering_id = r.offering_id
WHERE s.matric_no='TXN/S/002'
  AND o.semester = 'FIRST' AND o.course_id = (SELECT course_id FROM course WHERE course_code='TXNC01');

BEGIN;
INSERT INTO registration (student_id, offering_id, status)
SELECT s.student_id, o.offering_id, 'ACTIVE'
FROM student s, course_offering o
WHERE s.matric_no='TXN/S/002'
  AND o.semester = 'FIRST' AND o.course_id = (SELECT course_id FROM course WHERE course_code='TXNC01');
ROLLBACK;

SELECT 'B: rows after rollback = ' || count(*)::text AS message
FROM registration r
JOIN student s ON s.student_id = r.student_id
JOIN course_offering o ON o.offering_id = r.offering_id
WHERE s.matric_no='TXN/S/002'
  AND o.semester = 'FIRST' AND o.course_id = (SELECT course_id FROM course WHERE course_code='TXNC01');

-- =====================================================================
-- C. SAVEPOINT recovery
--    The outer transaction inserts a valid registration, then opens a
--    SAVEPOINT and tries a second insert that fails (capacity trigger
--    fired by exceeding the test offering's capacity). The savepoint is
--    rolled back to, and the outer transaction commits the first insert.
-- =====================================================================
\echo '=== C. SAVEPOINT recovery ==='

-- Use a fresh offering with capacity 1 so the second ACTIVE insert fails.
INSERT INTO course_offering
    (course_id, lecturer_id, semester, academic_year, capacity,
     offering_date, slot_day, start_time, end_time)
SELECT c.course_id, l.lecturer_id, 'SUMMER', '2025/2026', 1,
       CURRENT_DATE + 14, 4, '14:00', '16:00'
FROM course c, lecturer l
WHERE c.course_code='TXNC01' AND l.staff_no='TXN/L001'
  AND NOT EXISTS (SELECT 1 FROM course_offering x WHERE x.course_id=c.course_id AND x.semester='SUMMER' AND x.academic_year='2025/2026')
ON CONFLICT (course_id, semester, academic_year) DO NOTHING;

-- Make sure B's offering (FIRST sem) doesn't already have an ACTIVE row
-- from the rolled-back transaction (it doesn't, by design), so the first
-- insert below succeeds.
DO $$
DECLARE
    v_offering_first INT;   -- capacity 50, FIRST semester
    v_offering_cap1  INT;   -- capacity 1, SUMMER semester
    v_student        INT;
    v_second_student INT;
    v_savepoint_ok   BOOLEAN := FALSE;
BEGIN
    SELECT o.offering_id INTO v_offering_cap1
      FROM course_offering o
      JOIN course c ON c.course_id = o.course_id
     WHERE c.course_code='TXNC01' AND o.semester='SUMMER' AND o.academic_year='2025/2026';

    SELECT student_id INTO v_student        FROM student WHERE matric_no='TXN/S/001';
    SELECT student_id INTO v_second_student FROM student WHERE matric_no='TXN/S/002';

    BEGIN   -- outer transaction body (already in a DO block transaction)
        -- First insert: valid, lands inside the SUMMER offering.
        INSERT INTO registration (student_id, offering_id, status)
        VALUES (v_student, v_offering_cap1, 'ACTIVE');

        -- In PL/pgSQL a BEGIN ... EXCEPTION block is an implicit SAVEPOINT
        -- (SQL SAVEPOINT / ROLLBACK TO are not allowed inside DO).

        -- Second insert: should fail because the capacity-1 offering is now full.
        BEGIN
            INSERT INTO registration (student_id, offering_id, status)
            VALUES (v_second_student, v_offering_cap1, 'ACTIVE');
            RAISE NOTICE 'C: second insert unexpectedly succeeded';
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'C: second insert failed as expected: %', SQLERRM;
            v_savepoint_ok := TRUE;
        END;

        IF v_savepoint_ok THEN
            RAISE NOTICE 'C: recovered to savepoint; first insert remains valid';
        END IF;
    END;

    -- Confirm the first insert is still there (it will be when the DO block
    -- commits, since we did not raise an unhandled exception).
    RAISE NOTICE 'C: active rows in capacity-1 offering = %',
        (SELECT count(*) FROM registration
          WHERE offering_id = v_offering_cap1 AND status='ACTIVE');
END $$;

SELECT 'C: active rows in SUMMER capacity-1 offering = ' || count(*)::text AS message
FROM registration r
JOIN course_offering o ON o.offering_id = r.offering_id
JOIN course c          ON c.course_id   = o.course_id
WHERE c.course_code='TXNC01' AND o.semester='SUMMER' AND o.academic_year='2025/2026'
  AND r.status='ACTIVE';

\echo '01_transactions.sql finished'
