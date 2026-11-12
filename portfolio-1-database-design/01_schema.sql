-- 01_schema.sql
-- Creates the relational schema for St. Stephen Private University on the
-- ststephen database. Ten tables in 3NF (faculty, department, lecturer,
-- student, course, course_offering, registration, exam, result, fee_payment).
-- Includes PK, FK, UNIQUE, CHECK, a partial UNIQUE index (one ACTIVE
-- registration per student per course offering), and three BEFORE triggers
-- that enforce business rules: capacity on an offering, result must be for
-- an actively-registered student, and a lecturer cannot teach two clashing
-- weekly time slots. No CHECK uses CURRENT_DATE; date sanity rules that
-- depend on "today" are deferred to triggers.
--
-- Runs top to bottom with:  psql -d ststephen -v ON_ERROR_STOP=1 -f 01_schema.sql

\set ON_ERROR_STOP on

-- Database time zone: Africa/Lagos (WAT, UTC+01:00).
ALTER DATABASE ststephen SET timezone TO 'Africa/Lagos';
SET timezone TO 'Africa/Lagos';

-- Drop in dependency order so the file is re-runnable.
DROP TABLE IF EXISTS result            CASCADE;
DROP TABLE IF EXISTS fee_payment       CASCADE;
DROP TABLE IF EXISTS exam              CASCADE;
DROP TABLE IF EXISTS registration      CASCADE;
DROP TABLE IF EXISTS course_offering   CASCADE;
DROP TABLE IF EXISTS course            CASCADE;
DROP TABLE IF EXISTS student           CASCADE;
DROP TABLE IF EXISTS lecturer          CASCADE;
DROP TABLE IF EXISTS department        CASCADE;
DROP TABLE IF EXISTS faculty           CASCADE;

-- =====================================================================
-- faculty
-- =====================================================================
CREATE TABLE faculty (
    faculty_id      SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    faculty_code    CHAR(3)         NOT NULL UNIQUE,
    faculty_name    VARCHAR(80)     NOT NULL,
    dean_name       VARCHAR(80)     NOT NULL,
    CHECK (btrim(faculty_code) <> ''),
    CHECK (btrim(faculty_name) <> '')
);

-- =====================================================================
-- department
-- =====================================================================
CREATE TABLE department (
    department_id   SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    department_code CHAR(4)         NOT NULL UNIQUE,
    department_name VARCHAR(80)     NOT NULL,
    faculty_id      SMALLINT        NOT NULL REFERENCES faculty(faculty_id),
    hod_name        VARCHAR(80)     NOT NULL,
    CHECK (btrim(department_code) <> ''),
    CHECK (btrim(department_name) <> '')
);

-- =====================================================================
-- lecturer
-- =====================================================================
CREATE TABLE lecturer (
    lecturer_id     INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    staff_no        VARCHAR(20)     NOT NULL UNIQUE,
    full_name       VARCHAR(80)     NOT NULL,
    gender          CHAR(1)         NOT NULL CHECK (gender IN ('M','F')),
    department_id   SMALLINT        NOT NULL REFERENCES department(department_id),
    email           VARCHAR(120)    NOT NULL UNIQUE,
    hired_on        DATE            NOT NULL,
    CHECK (btrim(staff_no) <> ''),
    CHECK (btrim(full_name) <> ''),
    CHECK (email ~ '^[^@ ]+@[^@ ]+\.[^@ ]+$')
);

-- =====================================================================
-- student
-- =====================================================================
CREATE TABLE student (
    student_id      INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    matric_no       VARCHAR(20)     NOT NULL UNIQUE,
    full_name       VARCHAR(80)     NOT NULL,
    gender          CHAR(1)         NOT NULL CHECK (gender IN ('M','F')),
    department_id   SMALLINT        NOT NULL REFERENCES department(department_id),
    email           VARCHAR(120)    NOT NULL UNIQUE,
    enrolled_on     DATE            NOT NULL,
    status          VARCHAR(12)     NOT NULL DEFAULT 'ACTIVE'
                        CHECK (status IN ('ACTIVE','SUSPENDED','GRADUATED')),
    CHECK (btrim(matric_no) <> ''),
    CHECK (btrim(full_name) <> ''),
    CHECK (email ~ '^[^@ ]+@[^@ ]+\.[^@ ]+$')
);

-- =====================================================================
-- course
-- =====================================================================
CREATE TABLE course (
    course_id       INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    course_code     VARCHAR(10)     NOT NULL UNIQUE,
    course_title    VARCHAR(120)    NOT NULL,
    credit_units    SMALLINT        NOT NULL CHECK (credit_units > 0 AND credit_units <= 6),
    department_id   SMALLINT        NOT NULL REFERENCES department(department_id),
    level           SMALLINT        NOT NULL CHECK (level BETWEEN 100 AND 600),
    CHECK (btrim(course_code) <> ''),
    CHECK (btrim(course_title) <> '')
);

-- =====================================================================
-- course_offering
--   A course taught by a lecturer in a specific semester and academic year,
--   with a weekly time slot (slot_day, start_time, end_time) and capacity.
--   The (course_id, semester, academic_year) tuple is unique so a course
--   cannot be offered twice in the same semester.
-- =====================================================================
CREATE TABLE course_offering (
    offering_id     INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    course_id       INTEGER         NOT NULL REFERENCES course(course_id),
    lecturer_id     INTEGER         NOT NULL REFERENCES lecturer(lecturer_id),
    semester        VARCHAR(6)      NOT NULL CHECK (semester IN ('FIRST','SECOND','SUMMER')),
    academic_year   VARCHAR(9)      NOT NULL CHECK (academic_year ~ '^[0-9]{4}/[0-9]{4}$'),
    capacity        SMALLINT        NOT NULL CHECK (capacity > 0 AND capacity <= 1000),
    offering_date   DATE            NOT NULL,
    slot_day        SMALLINT        NOT NULL CHECK (slot_day BETWEEN 1 AND 7),  -- 1=Mon … 7=Sun
    start_time      TIME            NOT NULL,
    end_time        TIME            NOT NULL,
    CHECK (end_time > start_time),
    UNIQUE (course_id, semester, academic_year)
);

-- =====================================================================
-- registration
--   A student registered for an offering. status is ACTIVE, DROPPED or
--   COMPLETED. The partial UNIQUE index (created in 02_indexes.sql) enforces
--   one ACTIVE registration per (student_id, offering_id); DROPPED and
--   COMPLETED rows are not constrained.
-- =====================================================================
CREATE TABLE registration (
    registration_id BIGINT  GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    student_id      INTEGER         NOT NULL REFERENCES student(student_id),
    offering_id     INTEGER         NOT NULL REFERENCES course_offering(offering_id),
    registered_at   TIMESTAMPTZ     NOT NULL DEFAULT now(),
    status          VARCHAR(10)     NOT NULL DEFAULT 'ACTIVE'
                        CHECK (status IN ('ACTIVE','DROPPED','COMPLETED'))
);

-- =====================================================================
-- exam
-- =====================================================================
CREATE TABLE exam (
    exam_id         INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    offering_id     INTEGER         NOT NULL REFERENCES course_offering(offering_id),
    exam_type       VARCHAR(10)     NOT NULL CHECK (exam_type IN ('CA','MIDSEM','FINAL','RESIT')),
    exam_date       DATE            NOT NULL,
    max_score       SMALLINT        NOT NULL CHECK (max_score > 0 AND max_score <= 100),
    UNIQUE (offering_id, exam_type)
);

-- =====================================================================
-- result
--   A score for a student in an exam. The trigger ensures the student has
--   an ACTIVE registration on the offering the exam belongs to.
-- =====================================================================
CREATE TABLE result (
    result_id       BIGINT  GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    exam_id         INTEGER         NOT NULL REFERENCES exam(exam_id),
    student_id      INTEGER         NOT NULL REFERENCES student(student_id),
    score           NUMERIC(5,2)    NOT NULL CHECK (score >= 0),
    graded_at       TIMESTAMPTZ     NOT NULL DEFAULT now(),
    UNIQUE (exam_id, student_id),
    CHECK (score <= 100)
);

-- =====================================================================
-- fee_payment
--   Tuition and other fees paid in Naira. Fees owed are DERIVED from
--   registrations × credit units × per-unit rate minus sum(payments);
--   no totals are typed in.
-- =====================================================================
CREATE TABLE fee_payment (
    payment_id      BIGINT  GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    student_id      INTEGER         NOT NULL REFERENCES student(student_id),
    amount_naira    NUMERIC(12,2)   NOT NULL CHECK (amount_naira > 0),
    paid_on         DATE            NOT NULL,
    session         VARCHAR(9)      NOT NULL CHECK (session ~ '^[0-9]{4}/[0-9]{4}$'),
    method          VARCHAR(15)     NOT NULL CHECK (method IN ('CARD','BANK_TRANSFER','CASH','USSD'))
);

-- =====================================================================
-- Partial UNIQUE index: one ACTIVE registration per (student, offering).
-- This is created here (not just in 02_indexes.sql) because it is a core
-- business rule, not an optimisation. 02_indexes.sql still keeps it via
-- IF NOT EXISTS so re-runs are safe.
-- =====================================================================
CREATE UNIQUE INDEX IF NOT EXISTS uq_one_active_reg_per_student_offering
    ON registration (student_id, offering_id)
    WHERE status = 'ACTIVE';

-- =====================================================================
-- Trigger 1: enforce_capacity
--   Refuses a new ACTIVE registration if the offering is already full.
--   NB: this trigger races under concurrent READ COMMITTED transactions
--   (the race is demonstrated and fixed in portfolio-3-transactions-concurrency).
-- =====================================================================
CREATE OR REPLACE FUNCTION enforce_capacity() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
DECLARE
    cap           SMALLINT;
    active_count  BIGINT;
BEGIN
    SELECT capacity INTO cap FROM course_offering WHERE offering_id = NEW.offering_id;
    IF cap IS NULL THEN
        RAISE EXCEPTION 'course_offering % does not exist', NEW.offering_id;
    END IF;

    SELECT count(*) INTO active_count
      FROM registration
     WHERE offering_id = NEW.offering_id
       AND status = 'ACTIVE';

    IF active_count >= cap THEN
        RAISE EXCEPTION 'offering % is full (capacity %, active %)',
            NEW.offering_id, cap, active_count
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_capacity ON registration;
CREATE TRIGGER trg_enforce_capacity
BEFORE INSERT OR UPDATE OF status ON registration
FOR EACH ROW
WHEN (NEW.status = 'ACTIVE')
EXECUTE FUNCTION enforce_capacity();

-- =====================================================================
-- Trigger 2: enforce_result_registered
--   Refuses a result for a student who has no ACTIVE registration on the
--   offering the exam belongs to.
-- =====================================================================
CREATE OR REPLACE FUNCTION enforce_result_registered() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
DECLARE
    found INT;
BEGIN
    SELECT 1 INTO found
      FROM registration r
      JOIN exam e ON e.offering_id = r.offering_id
     WHERE r.student_id = NEW.student_id
       AND e.exam_id    = NEW.exam_id
       AND r.status     = 'ACTIVE'
     LIMIT 1;

    IF found IS NULL THEN
        RAISE EXCEPTION 'student % has no ACTIVE registration for exam %',
            NEW.student_id, NEW.exam_id
            USING ERRCODE = 'foreign_key_violation';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_result_registered ON result;
CREATE TRIGGER trg_result_registered
BEFORE INSERT OR UPDATE ON result
FOR EACH ROW
EXECUTE FUNCTION enforce_result_registered();

-- =====================================================================
-- Trigger 3: enforce_no_lecturer_clash
--   Refuses a course offering that puts a lecturer in two overlapping
--   weekly time slots on the same day.
-- =====================================================================
CREATE OR REPLACE FUNCTION enforce_no_lecturer_clash() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
DECLARE
    clash INT;
BEGIN
    SELECT 1 INTO clash
      FROM course_offering o
     WHERE o.lecturer_id = NEW.lecturer_id
       AND o.offering_id <> NEW.offering_id
       AND o.slot_day    = NEW.slot_day
       AND o.start_time  < NEW.end_time
       AND o.end_time    > NEW.start_time
     LIMIT 1;

    IF clash IS NOT NULL THEN
        RAISE EXCEPTION 'lecturer % already has a clashing slot on day %',
            NEW.lecturer_id, NEW.slot_day
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_no_lecturer_clash ON course_offering;
CREATE TRIGGER trg_no_lecturer_clash
BEFORE INSERT OR UPDATE OF lecturer_id, slot_day, start_time, end_time ON course_offering
FOR EACH ROW
EXECUTE FUNCTION enforce_no_lecturer_clash();

-- =====================================================================
-- Trigger 4 (bonus): enforce_no_past_exam_date
--   Replaces what would otherwise be a CHECK (exam_date >= CURRENT_DATE)
--   pattern, which PostgreSQL does not allow (CURRENT_DATE is not immutable).
-- =====================================================================
CREATE OR REPLACE FUNCTION enforce_no_past_exam_date() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.exam_date < CURRENT_DATE THEN
        RAISE EXCEPTION 'exam_date cannot be in the past: %', NEW.exam_date
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_no_past_exam_date ON exam;
CREATE TRIGGER trg_no_past_exam_date
BEFORE INSERT OR UPDATE OF exam_date ON exam
FOR EACH ROW
EXECUTE FUNCTION enforce_no_past_exam_date();

-- Sanity check at end of file.
SELECT '01_schema.sql loaded OK' AS message;
