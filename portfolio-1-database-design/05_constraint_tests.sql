-- 05_constraint_tests.sql
-- Constraint and trigger tests for the St. Stephen schema.
-- 10 tests + 1 control. Each test builds its own data inside a
-- BEGIN … ROLLBACK block, attempts the operation that must fail, catches
-- the exception, prints PASS or FAIL with the SQLSTATE it got, then
-- rolls back so the next test starts from a clean state.
--
-- Run with:  psql -d ststephen -v ON_ERROR_STOP=1 -f 05_constraint_tests.sql

\set ON_ERROR_STOP on
SET timezone TO 'Africa/Lagos';

-- Helper: a small notice so the student can see the script started.
\echo 'Running 05_constraint_tests.sql — 10 expected failures + 1 control'

-- =====================================================================
-- TEST 1  —  FK violation: registration references a non-existent student.
-- Expected SQLSTATE: 23503 (foreign_key_violation)
-- =====================================================================
BEGIN;
INSERT INTO faculty (faculty_code, faculty_name, dean_name)
    VALUES ('T01', 'Test Faculty 01', 'Prof. Test 01');
INSERT INTO department (department_code, department_name, faculty_id, hod_name)
    VALUES ('TD01', 'Test Dept 01',
            (SELECT faculty_id FROM faculty WHERE faculty_code='T01'),
            'Dr. HOD 01');
INSERT INTO lecturer (staff_no, full_name, gender, department_id, email, hired_on)
    VALUES ('T01/001', 'Dr. Test Lecturer 01', 'M',
            (SELECT department_id FROM department WHERE department_code='TD01'),
            't01.001@ststephen.edu.ng', CURRENT_DATE);
INSERT INTO course (course_code, course_title, credit_units, department_id, level)
    VALUES ('T01C01', 'Test Course 01', 3,
            (SELECT department_id FROM department WHERE department_code='TD01'), 100);
INSERT INTO course_offering
    (course_id, lecturer_id, semester, academic_year, capacity, offering_date,
     slot_day, start_time, end_time)
SELECT c.course_id, l.lecturer_id, 'FIRST', '2025/2026', 30, CURRENT_DATE + 7,
       1, '08:00', '10:00'
FROM course c, lecturer l
WHERE c.course_code='T01C01' AND l.staff_no='T01/001';

DO $$
DECLARE
    v_offering INT;
BEGIN
    SELECT offering_id INTO v_offering FROM course_offering
     WHERE course_id = (SELECT course_id FROM course WHERE course_code='T01C01');
    BEGIN
        INSERT INTO registration (student_id, offering_id, status)
        VALUES (99999999, v_offering, 'ACTIVE');
        RAISE NOTICE 'TEST 1 FAIL: FK on registration.student_id did not fire';
    EXCEPTION
        WHEN foreign_key_violation THEN
            RAISE NOTICE 'TEST 1 PASS (SQLSTATE %)', SQLSTATE;
        WHEN OTHERS THEN
            RAISE NOTICE 'TEST 1 FAIL — expected 23503, got %: %', SQLSTATE, SQLERRM;
    END;
END $$;
ROLLBACK;

-- =====================================================================
-- TEST 2  —  FK violation: exam references a non-existent offering.
-- Expected SQLSTATE: 23503
-- =====================================================================
BEGIN;
INSERT INTO faculty (faculty_code, faculty_name, dean_name)
    VALUES ('T02','Test Faculty 02','Prof. Test 02');
INSERT INTO department (department_code, department_name, faculty_id, hod_name)
    VALUES ('TD02','Test Dept 02',
            (SELECT faculty_id FROM faculty WHERE faculty_code='T02'),
            'Dr. HOD 02');
INSERT INTO student (matric_no, full_name, gender, department_id, email, enrolled_on, status)
    VALUES ('T02/STU/001','Test Student 02','M',
            (SELECT department_id FROM department WHERE department_code='TD02'),
            't02.stu.001@ststephen.edu.ng', CURRENT_DATE, 'ACTIVE');

DO $$
DECLARE
    v_student INT;
BEGIN
    SELECT student_id INTO v_student FROM student WHERE matric_no='T02/STU/001';
    BEGIN
        -- exam.offering_id FK (a registration insert would hit the capacity trigger first)
        INSERT INTO exam (offering_id, exam_type, exam_date, max_score)
        VALUES (99999999, 'FINAL', CURRENT_DATE + 30, 100);
        RAISE NOTICE 'TEST 2 FAIL: FK on exam.offering_id did not fire';
    EXCEPTION
        WHEN foreign_key_violation THEN
            RAISE NOTICE 'TEST 2 PASS (SQLSTATE %)', SQLSTATE;
        WHEN OTHERS THEN
            RAISE NOTICE 'TEST 2 FAIL — expected 23503, got %: %', SQLSTATE, SQLERRM;
    END;
END $$;
ROLLBACK;

-- =====================================================================
-- TEST 3  —  UNIQUE violation: two offerings with same (course, semester, year).
-- Expected SQLSTATE: 23505 (unique_violation)
-- =====================================================================
BEGIN;
INSERT INTO faculty (faculty_code, faculty_name, dean_name)
    VALUES ('T03','Test Faculty 03','Prof. Test 03');
INSERT INTO department (department_code, department_name, faculty_id, hod_name)
    VALUES ('TD03','Test Dept 03',
            (SELECT faculty_id FROM faculty WHERE faculty_code='T03'),
            'Dr. HOD 03');
INSERT INTO lecturer (staff_no, full_name, gender, department_id, email, hired_on)
    VALUES ('T03/001','Dr. Test Lecturer 03','F',
            (SELECT department_id FROM department WHERE department_code='TD03'),
            't03.001@ststephen.edu.ng', CURRENT_DATE);
INSERT INTO course (course_code, course_title, credit_units, department_id, level)
    VALUES ('T03C01','Test Course 03',3,
            (SELECT department_id FROM department WHERE department_code='TD03'), 200);
INSERT INTO course_offering
    (course_id, lecturer_id, semester, academic_year, capacity, offering_date,
     slot_day, start_time, end_time)
SELECT c.course_id, l.lecturer_id, 'FIRST', '2025/2026', 40, CURRENT_DATE + 7,
       2, '10:00', '12:00'
FROM course c, lecturer l
WHERE c.course_code='T03C01' AND l.staff_no='T03/001';

DO $$
DECLARE
    v_course INT;
    v_lect   INT;
BEGIN
    SELECT course_id INTO v_course FROM course WHERE course_code='T03C01';
    SELECT lecturer_id INTO v_lect FROM lecturer WHERE staff_no='T03/001';
    BEGIN
        INSERT INTO course_offering
            (course_id, lecturer_id, semester, academic_year, capacity,
             offering_date, slot_day, start_time, end_time)
        VALUES (v_course, v_lect, 'FIRST', '2025/2026', 30,
                CURRENT_DATE + 7, 3, '14:00', '16:00');
        RAISE NOTICE 'TEST 3 FAIL: UNIQUE(course, semester, year) did not fire';
    EXCEPTION
        WHEN unique_violation THEN
            RAISE NOTICE 'TEST 3 PASS (SQLSTATE %)', SQLSTATE;
        WHEN OTHERS THEN
            RAISE NOTICE 'TEST 3 FAIL — expected 23505, got %: %', SQLSTATE, SQLERRM;
    END;
END $$;
ROLLBACK;

-- =====================================================================
-- TEST 4  —  CHECK violation: credit_units out of range (1..6).
-- Expected SQLSTATE: 23514 (check_violation)
-- =====================================================================
BEGIN;
INSERT INTO faculty (faculty_code, faculty_name, dean_name)
    VALUES ('T04','Test Faculty 04','Prof. Test 04');
INSERT INTO department (department_code, department_name, faculty_id, hod_name)
    VALUES ('TD04','Test Dept 04',
            (SELECT faculty_id FROM faculty WHERE faculty_code='T04'),
            'Dr. HOD 04');

DO $$
DECLARE
    v_dept INT;
BEGIN
    SELECT department_id INTO v_dept FROM department WHERE department_code='TD04';
    BEGIN
        INSERT INTO course (course_code, course_title, credit_units, department_id, level)
        VALUES ('T04CBAD','Test Course Bad Units', 99, v_dept, 100);
        RAISE NOTICE 'TEST 4 FAIL: CHECK (credit_units <= 6) did not fire';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE 'TEST 4 PASS (SQLSTATE %)', SQLSTATE;
        WHEN OTHERS THEN
            RAISE NOTICE 'TEST 4 FAIL — expected 23514, got %: %', SQLSTATE, SQLERRM;
    END;
END $$;
ROLLBACK;

-- =====================================================================
-- TEST 5  —  CHECK violation: invalid student status.
-- Expected SQLSTATE: 23514
-- =====================================================================
BEGIN;
INSERT INTO faculty (faculty_code, faculty_name, dean_name)
    VALUES ('T05','Test Faculty 05','Prof. Test 05');
INSERT INTO department (department_code, department_name, faculty_id, hod_name)
    VALUES ('TD05','Test Dept 05',
            (SELECT faculty_id FROM faculty WHERE faculty_code='T05'),
            'Dr. HOD 05');

DO $$
DECLARE
    v_dept INT;
BEGIN
    SELECT department_id INTO v_dept FROM department WHERE department_code='TD05';
    BEGIN
        INSERT INTO student (matric_no, full_name, gender, department_id, email,
                             enrolled_on, status)
        VALUES ('T05/STU/BAD','Bad Status Student','M', v_dept,
                't05.bad@ststephen.edu.ng', CURRENT_DATE, 'PROBATION');
        RAISE NOTICE 'TEST 5 FAIL: CHECK on student.status did not fire';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE 'TEST 5 PASS (SQLSTATE %)', SQLSTATE;
        WHEN OTHERS THEN
            RAISE NOTICE 'TEST 5 FAIL — expected 23514, got %: %', SQLSTATE, SQLERRM;
    END;
END $$;
ROLLBACK;

-- =====================================================================
-- TEST 6  —  Trigger enforce_capacity: offering full, new ACTIVE row blocked.
-- Expected SQLSTATE: 23514 (the trigger raises with ERRCODE='check_violation')
-- =====================================================================
BEGIN;
INSERT INTO faculty (faculty_code, faculty_name, dean_name)
    VALUES ('T06','Test Faculty 06','Prof. Test 06');
INSERT INTO department (department_code, department_name, faculty_id, hod_name)
    VALUES ('TD06','Test Dept 06',
            (SELECT faculty_id FROM faculty WHERE faculty_code='T06'),
            'Dr. HOD 06');
INSERT INTO lecturer (staff_no, full_name, gender, department_id, email, hired_on)
    VALUES ('T06/001','Dr. Test Lecturer 06','M',
            (SELECT department_id FROM department WHERE department_code='TD06'),
            't06.001@ststephen.edu.ng', CURRENT_DATE);
INSERT INTO course (course_code, course_title, credit_units, department_id, level)
    VALUES ('T06C01','Test Course 06',3,
            (SELECT department_id FROM department WHERE department_code='TD06'), 300);
INSERT INTO course_offering
    (course_id, lecturer_id, semester, academic_year, capacity, offering_date,
     slot_day, start_time, end_time)
SELECT c.course_id, l.lecturer_id, 'FIRST', '2025/2026', 1, CURRENT_DATE + 7,
       4, '08:00', '10:00'
FROM course c, lecturer l
WHERE c.course_code='T06C01' AND l.staff_no='T06/001';
INSERT INTO student (matric_no, full_name, gender, department_id, email, enrolled_on, status)
    VALUES ('T06/STU/001','Capacity Student A','M',
            (SELECT department_id FROM department WHERE department_code='TD06'),
            't06.stu.001@ststephen.edu.ng', CURRENT_DATE, 'ACTIVE');
INSERT INTO student (matric_no, full_name, gender, department_id, email, enrolled_on, status)
    VALUES ('T06/STU/002','Capacity Student B','F',
            (SELECT department_id FROM department WHERE department_code='TD06'),
            't06.stu.002@ststephen.edu.ng', CURRENT_DATE, 'ACTIVE');

DO $$
DECLARE
    v_offering INT;
    v_a        INT;
    v_b        INT;
BEGIN
    SELECT offering_id INTO v_offering FROM course_offering
     WHERE course_id = (SELECT course_id FROM course WHERE course_code='T06C01');
    SELECT student_id INTO v_a FROM student WHERE matric_no='T06/STU/001';
    SELECT student_id INTO v_b FROM student WHERE matric_no='T06/STU/002';

    -- First ACTIVE registration fills the only slot (capacity = 1).
    INSERT INTO registration (student_id, offering_id, status)
    VALUES (v_a, v_offering, 'ACTIVE');

    -- Second ACTIVE registration from a different student must fail.
    BEGIN
        INSERT INTO registration (student_id, offering_id, status)
        VALUES (v_b, v_offering, 'ACTIVE');
        RAISE NOTICE 'TEST 6 FAIL: enforce_capacity trigger did not fire';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE 'TEST 6 PASS (SQLSTATE %)', SQLSTATE;
        WHEN OTHERS THEN
            RAISE NOTICE 'TEST 6 FAIL — expected 23514, got %: %', SQLSTATE, SQLERRM;
    END;
END $$;
ROLLBACK;

-- =====================================================================
-- TEST 7  —  Trigger enforce_result_registered: result for an unregistered
-- student is blocked.
-- Expected SQLSTATE: 23503 (the trigger raises with ERRCODE='foreign_key_violation')
-- =====================================================================
BEGIN;
INSERT INTO faculty (faculty_code, faculty_name, dean_name)
    VALUES ('T07','Test Faculty 07','Prof. Test 07');
INSERT INTO department (department_code, department_name, faculty_id, hod_name)
    VALUES ('TD07','Test Dept 07',
            (SELECT faculty_id FROM faculty WHERE faculty_code='T07'),
            'Dr. HOD 07');
INSERT INTO lecturer (staff_no, full_name, gender, department_id, email, hired_on)
    VALUES ('T07/001','Dr. Test Lecturer 07','F',
            (SELECT department_id FROM department WHERE department_code='TD07'),
            't07.001@ststephen.edu.ng', CURRENT_DATE);
INSERT INTO course (course_code, course_title, credit_units, department_id, level)
    VALUES ('T07C01','Test Course 07',3,
            (SELECT department_id FROM department WHERE department_code='TD07'), 300);
INSERT INTO course_offering
    (course_id, lecturer_id, semester, academic_year, capacity, offering_date,
     slot_day, start_time, end_time)
SELECT c.course_id, l.lecturer_id, 'FIRST', '2025/2026', 30, CURRENT_DATE + 7,
       5, '08:00', '10:00'
FROM course c, lecturer l
WHERE c.course_code='T07C01' AND l.staff_no='T07/001';
INSERT INTO exam (offering_id, exam_type, exam_date, max_score)
SELECT offering_id, 'CA', CURRENT_DATE + 14, 20
  FROM course_offering
 WHERE course_id = (SELECT course_id FROM course WHERE course_code='T07C01');
INSERT INTO student (matric_no, full_name, gender, department_id, email, enrolled_on, status)
    VALUES ('T07/STU/001','Unregistered Student','M',
            (SELECT department_id FROM department WHERE department_code='TD07'),
            't07.stu.001@ststephen.edu.ng', CURRENT_DATE, 'ACTIVE');

DO $$
DECLARE
    v_exam    INT;
    v_student INT;
BEGIN
    SELECT exam_id    INTO v_exam    FROM exam e
     JOIN course_offering o ON o.offering_id = e.offering_id
     JOIN course c          ON c.course_id = o.course_id
     WHERE c.course_code='T07C01' AND e.exam_type='CA';
    SELECT student_id INTO v_student FROM student WHERE matric_no='T07/STU/001';

    BEGIN
        INSERT INTO result (exam_id, student_id, score)
        VALUES (v_exam, v_student, 15.00);
        RAISE NOTICE 'TEST 7 FAIL: enforce_result_registered trigger did not fire';
    EXCEPTION
        WHEN foreign_key_violation THEN
            RAISE NOTICE 'TEST 7 PASS (SQLSTATE %)', SQLSTATE;
        WHEN OTHERS THEN
            RAISE NOTICE 'TEST 7 FAIL — expected 23503, got %: %', SQLSTATE, SQLERRM;
    END;
END $$;
ROLLBACK;

-- =====================================================================
-- TEST 8  —  Trigger enforce_no_lecturer_clash: two overlapping slots for
-- the same lecturer on the same day are blocked.
-- Expected SQLSTATE: 23514
-- =====================================================================
BEGIN;
INSERT INTO faculty (faculty_code, faculty_name, dean_name)
    VALUES ('T08','Test Faculty 08','Prof. Test 08');
INSERT INTO department (department_code, department_name, faculty_id, hod_name)
    VALUES ('TD08','Test Dept 08',
            (SELECT faculty_id FROM faculty WHERE faculty_code='T08'),
            'Dr. HOD 08');
INSERT INTO lecturer (staff_no, full_name, gender, department_id, email, hired_on)
    VALUES ('T08/001','Dr. Clashing Lecturer','M',
            (SELECT department_id FROM department WHERE department_code='TD08'),
            't08.001@ststephen.edu.ng', CURRENT_DATE);
INSERT INTO course (course_code, course_title, credit_units, department_id, level)
    VALUES ('T08C01','Clash Course A',3,
            (SELECT department_id FROM department WHERE department_code='TD08'), 300);
INSERT INTO course (course_code, course_title, credit_units, department_id, level)
    VALUES ('T08C02','Clash Course B',3,
            (SELECT department_id FROM department WHERE department_code='TD08'), 300);
-- First offering: Monday 08:00–10:00
INSERT INTO course_offering
    (course_id, lecturer_id, semester, academic_year, capacity, offering_date,
     slot_day, start_time, end_time)
SELECT c.course_id, l.lecturer_id, 'FIRST', '2025/2026', 40, CURRENT_DATE + 7,
       1, '08:00', '10:00'
FROM course c, lecturer l
WHERE c.course_code='T08C01' AND l.staff_no='T08/001';

DO $$
DECLARE
    v_course INT;
    v_lect   INT;
BEGIN
    SELECT course_id    INTO v_course FROM course WHERE course_code='T08C02';
    SELECT lecturer_id  INTO v_lect   FROM lecturer WHERE staff_no='T08/001';
    BEGIN
        -- Second offering for same lecturer, same day, 09:00–11:00 → overlaps.
        INSERT INTO course_offering
            (course_id, lecturer_id, semester, academic_year, capacity,
             offering_date, slot_day, start_time, end_time)
        VALUES (v_course, v_lect, 'SECOND', '2025/2026', 40,
                CURRENT_DATE + 7, 1, '09:00', '11:00');
        RAISE NOTICE 'TEST 8 FAIL: enforce_no_lecturer_clash trigger did not fire';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE 'TEST 8 PASS (SQLSTATE %)', SQLSTATE;
        WHEN OTHERS THEN
            RAISE NOTICE 'TEST 8 FAIL — expected 23514, got %: %', SQLSTATE, SQLERRM;
    END;
END $$;
ROLLBACK;

-- =====================================================================
-- TEST 9  —  Partial UNIQUE index: two ACTIVE registrations for the same
-- (student, offering) pair are blocked (the second one).
-- Expected SQLSTATE: 23505 (unique_violation)
-- =====================================================================
BEGIN;
INSERT INTO faculty (faculty_code, faculty_name, dean_name)
    VALUES ('T09','Test Faculty 09','Prof. Test 09');
INSERT INTO department (department_code, department_name, faculty_id, hod_name)
    VALUES ('TD09','Test Dept 09',
            (SELECT faculty_id FROM faculty WHERE faculty_code='T09'),
            'Dr. HOD 09');
INSERT INTO lecturer (staff_no, full_name, gender, department_id, email, hired_on)
    VALUES ('T09/001','Dr. Test Lecturer 09','F',
            (SELECT department_id FROM department WHERE department_code='TD09'),
            't09.001@ststephen.edu.ng', CURRENT_DATE);
INSERT INTO course (course_code, course_title, credit_units, department_id, level)
    VALUES ('T09C01','Test Course 09',3,
            (SELECT department_id FROM department WHERE department_code='TD09'), 300);
INSERT INTO course_offering
    (course_id, lecturer_id, semester, academic_year, capacity, offering_date,
     slot_day, start_time, end_time)
SELECT c.course_id, l.lecturer_id, 'FIRST', '2025/2026', 30, CURRENT_DATE + 7,
       6, '08:00', '10:00'
FROM course c, lecturer l
WHERE c.course_code='T09C01' AND l.staff_no='T09/001';
INSERT INTO student (matric_no, full_name, gender, department_id, email, enrolled_on, status)
    VALUES ('T09/STU/001','Duplicate Reg Student','M',
            (SELECT department_id FROM department WHERE department_code='TD09'),
            't09.stu.001@ststephen.edu.ng', CURRENT_DATE, 'ACTIVE');

DO $$
DECLARE
    v_offering INT;
    v_student  INT;
BEGIN
    SELECT offering_id INTO v_offering FROM course_offering
     WHERE course_id = (SELECT course_id FROM course WHERE course_code='T09C01');
    SELECT student_id INTO v_student FROM student WHERE matric_no='T09/STU/001';

    INSERT INTO registration (student_id, offering_id, status)
    VALUES (v_student, v_offering, 'ACTIVE');

    BEGIN
        INSERT INTO registration (student_id, offering_id, status)
        VALUES (v_student, v_offering, 'ACTIVE');
        RAISE NOTICE 'TEST 9 FAIL: partial UNIQUE index did not fire';
    EXCEPTION
        WHEN unique_violation THEN
            RAISE NOTICE 'TEST 9 PASS (SQLSTATE %)', SQLSTATE;
        WHEN OTHERS THEN
            RAISE NOTICE 'TEST 9 FAIL — expected 23505, got %: %', SQLSTATE, SQLERRM;
    END;
END $$;
ROLLBACK;

-- =====================================================================
-- TEST 10 —  Trigger enforce_no_past_exam_date: an exam dated in the past
-- is blocked.
-- Expected SQLSTATE: 23514
-- =====================================================================
BEGIN;
INSERT INTO faculty (faculty_code, faculty_name, dean_name)
    VALUES ('T10','Test Faculty 10','Prof. Test 10');
INSERT INTO department (department_code, department_name, faculty_id, hod_name)
    VALUES ('TD10','Test Dept 10',
            (SELECT faculty_id FROM faculty WHERE faculty_code='T10'),
            'Dr. HOD 10');
INSERT INTO lecturer (staff_no, full_name, gender, department_id, email, hired_on)
    VALUES ('T10/001','Dr. Test Lecturer 10','M',
            (SELECT department_id FROM department WHERE department_code='TD10'),
            't10.001@ststephen.edu.ng', CURRENT_DATE);
INSERT INTO course (course_code, course_title, credit_units, department_id, level)
    VALUES ('T10C01','Test Course 10',3,
            (SELECT department_id FROM department WHERE department_code='TD10'), 400);
INSERT INTO course_offering
    (course_id, lecturer_id, semester, academic_year, capacity, offering_date,
     slot_day, start_time, end_time)
SELECT c.course_id, l.lecturer_id, 'FIRST', '2025/2026', 30, CURRENT_DATE + 7,
       7, '08:00', '10:00'
FROM course c, lecturer l
WHERE c.course_code='T10C01' AND l.staff_no='T10/001';

DO $$
DECLARE
    v_offering INT;
BEGIN
    SELECT offering_id INTO v_offering FROM course_offering
     WHERE course_id = (SELECT course_id FROM course WHERE course_code='T10C01');
    BEGIN
        INSERT INTO exam (offering_id, exam_type, exam_date, max_score)
        VALUES (v_offering, 'CA', CURRENT_DATE - 1, 20);
        RAISE NOTICE 'TEST 10 FAIL: enforce_no_past_exam_date trigger did not fire';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE 'TEST 10 PASS (SQLSTATE %)', SQLSTATE;
        WHEN OTHERS THEN
            RAISE NOTICE 'TEST 10 FAIL — expected 23514, got %: %', SQLSTATE, SQLERRM;
    END;
END $$;
ROLLBACK;

-- =====================================================================
-- TEST 11 (CONTROL) —  A fully valid registration must succeed.
-- Expected: no exception.
-- =====================================================================
BEGIN;
INSERT INTO faculty (faculty_code, faculty_name, dean_name)
    VALUES ('T11','Test Faculty 11','Prof. Test 11');
INSERT INTO department (department_code, department_name, faculty_id, hod_name)
    VALUES ('TD11','Test Dept 11',
            (SELECT faculty_id FROM faculty WHERE faculty_code='T11'),
            'Dr. HOD 11');
INSERT INTO lecturer (staff_no, full_name, gender, department_id, email, hired_on)
    VALUES ('T11/001','Dr. Control Lecturer','F',
            (SELECT department_id FROM department WHERE department_code='TD11'),
            't11.001@ststephen.edu.ng', CURRENT_DATE);
INSERT INTO course (course_code, course_title, credit_units, department_id, level)
    VALUES ('T11C01','Control Course',3,
            (SELECT department_id FROM department WHERE department_code='TD11'), 400);
INSERT INTO course_offering
    (course_id, lecturer_id, semester, academic_year, capacity, offering_date,
     slot_day, start_time, end_time)
SELECT c.course_id, l.lecturer_id, 'FIRST', '2025/2026', 30, CURRENT_DATE + 7,
       1, '08:00', '10:00'
FROM course c, lecturer l
WHERE c.course_code='T11C01' AND l.staff_no='T11/001';
INSERT INTO student (matric_no, full_name, gender, department_id, email, enrolled_on, status)
    VALUES ('T11/STU/001','Control Student','M',
            (SELECT department_id FROM department WHERE department_code='TD11'),
            't11.stu.001@ststephen.edu.ng', CURRENT_DATE, 'ACTIVE');

DO $$
DECLARE
    v_offering INT;
    v_student  INT;
    v_reg      BIGINT;
BEGIN
    SELECT offering_id INTO v_offering FROM course_offering
     WHERE course_id = (SELECT course_id FROM course WHERE course_code='T11C01');
    SELECT student_id INTO v_student FROM student WHERE matric_no='T11/STU/001';

    INSERT INTO registration (student_id, offering_id, status)
    VALUES (v_student, v_offering, 'ACTIVE')
    RETURNING registration_id INTO v_reg;

    IF v_reg IS NOT NULL THEN
        RAISE NOTICE 'TEST 11 (control) PASS — registration_id = %', v_reg;
    ELSE
        RAISE NOTICE 'TEST 11 (control) FAIL — no row inserted';
    END IF;
END $$;
ROLLBACK;

\echo '05_constraint_tests.sql finished'
