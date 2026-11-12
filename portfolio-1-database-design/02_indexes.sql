-- 02_indexes.sql
-- Creates the indexes needed by the P1 triggers and by the P2/P3/P5
-- reports. Every foreign key that a trigger or a report reads is indexed,
-- plus a few selective secondary indexes used by the queries in
-- portfolio-2-query-optimisation. The partial UNIQUE index from
-- 01_schema.sql is recreated with IF NOT EXISTS so the file is re-runnable.
--
-- Runs top to bottom with:  psql -d ststephen -v ON_ERROR_STOP=1 -f 02_indexes.sql

\set ON_ERROR_STOP on
SET timezone TO 'Africa/Lagos';

-- ---------------------------------------------------------------------
-- Re-declare the core partial UNIQUE index (created in 01_schema.sql as
-- a business rule; kept here so the optimisation file is self-describing).
-- ---------------------------------------------------------------------
CREATE UNIQUE INDEX IF NOT EXISTS uq_one_active_reg_per_student_offering
    ON registration (student_id, offering_id)
    WHERE status = 'ACTIVE';

-- ---------------------------------------------------------------------
-- Foreign keys used by triggers or reports.
-- ---------------------------------------------------------------------

-- department.faculty_id  (used by joins, not a trigger, but cheap)
CREATE INDEX IF NOT EXISTS idx_department_faculty
    ON department (faculty_id);

-- lecturer.department_id  (used by joins)
CREATE INDEX IF NOT EXISTS idx_lecturer_department
    ON lecturer (department_id);

-- student.department_id  (used by joins and reports)
CREATE INDEX IF NOT EXISTS idx_student_department
    ON student (department_id);

-- course.department_id  (used by joins)
CREATE INDEX IF NOT EXISTS idx_course_department
    ON course (department_id);

-- course_offering.course_id  (used by joins and reports)
CREATE INDEX IF NOT EXISTS idx_offering_course
    ON course_offering (course_id);

-- course_offering.lecturer_id  (used by the lecturer clash trigger AND by
-- the lecturer-clash trigger's EXISTS lookup AND by reports)
CREATE INDEX IF NOT EXISTS idx_offering_lecturer
    ON course_offering (lecturer_id);

-- registration.offering_id  (used by the capacity trigger's count(*) AND
-- by every report that joins registration -> offering)
CREATE INDEX IF NOT EXISTS idx_registration_offering
    ON registration (offering_id);

-- registration.student_id  (used by reports and by the result trigger's
-- reverse lookup)
CREATE INDEX IF NOT EXISTS idx_registration_student
    ON registration (student_id);

-- exam.offering_id  (used by the result trigger and reports)
CREATE INDEX IF NOT EXISTS idx_exam_offering
    ON exam (offering_id);

-- result.exam_id  (used by joins in reports)
CREATE INDEX IF NOT EXISTS idx_result_exam
    ON result (exam_id);

-- result.student_id  (used by joins in reports)
CREATE INDEX IF NOT EXISTS idx_result_student
    ON result (student_id);

-- fee_payment.student_id  (used by joins in reports)
CREATE INDEX IF NOT EXISTS idx_payment_student
    ON fee_payment (student_id);

-- ---------------------------------------------------------------------
-- Selective secondary indexes used by portfolio-2-query-optimisation.
-- These are the indexes that 02_explain_analyze.sql will DROP and RECREATE
-- to demonstrate the speed-up on the four selective queries.
-- ---------------------------------------------------------------------

-- Q1: one student's full transcript — selective on student_id.
CREATE INDEX IF NOT EXISTS idx_result_student_graded
    ON result (student_id, graded_at DESC);

-- Q2: one department's students — selective on department_id.
-- (idx_student_department already covers this; no duplicate needed.)

-- Q3: one lecturer's offerings — selective on lecturer_id.
-- (idx_offering_lecturer already covers this.)

-- Q4: registrations in the last 30 days — selective on registered_at.
CREATE INDEX IF NOT EXISTS idx_registration_recent
    ON registration (registered_at DESC)
    WHERE status = 'ACTIVE';

-- fee_payment.paid_on  (used by a finance report)
CREATE INDEX IF NOT EXISTS idx_payment_paid_on
    ON fee_payment (paid_on DESC);

SELECT '02_indexes.sql loaded OK' AS message;
