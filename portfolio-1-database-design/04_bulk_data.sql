-- 04_bulk_data.sql
-- Generates the volume data for St. Stephen USMS using generate_series
-- directly inside SQL (no Python loops). Adds:
--   * 1,000 new students (total ~1,020)
--   * 96 new courses (total ~108)
--   * 500 new course offerings with no lecturer clashes and no
--     (course, semester, year) duplicates
--   * ~60,000 registrations distributed across offerings, each offering
--     gets fewer ACTIVE rows than its capacity so the capacity trigger
--     never fires; ~10% DROPPED and ~4% COMPLETED for variety
--   * ~30,000 results for ACTIVE registrations on the FINAL exam of each
--     offering (the result trigger passes by construction)
--   * ~2,000 fee payments in Naira
--
-- All dates are RELATIVE to CURRENT_DATE: history (up to ~1 year back)
-- plus the next 14 days, with some registrations whose registered_at is
-- in the near future.
--
-- Does NOT truncate rows that later demos use; appends only.
-- Designed to run in under 30 seconds on a GitHub Codespaces instance.
--
-- Runs top to bottom with:  psql -d ststephen -v ON_ERROR_STOP=1 -f 04_bulk_data.sql

\set ON_ERROR_STOP on
SET timezone TO 'Africa/Lagos';

-- =====================================================================
-- 1. 1,000 new students with gender-matched Nigerian names.
-- =====================================================================
WITH male_names AS (
    SELECT ARRAY[
        'Tunde','Chinedu','Musa','Emeka','Bola','Sani','Yakubu','Sadiq',
        'Adamu','Samuel','Daniel','Tobias','Chuka','Basil','Kunle','Femi',
        'Ifeanyi','Obinna','Seyi','Tobi','Jide','Wale','Tope','Bayo',
        'Henry','Ibrahim','Nasir','Dauda','Kabir','Uche'
    ] AS names
),
female_names AS (
    SELECT ARRAY[
        'Ngozi','Folake','Aisha','Chioma','Adaeze','Bisi','Halima','Zainab',
        'Amarachi','Fatima','Aminata','Chidinma','Ifeoma','Nneka','Oluwaseun',
        'Sade','Tari','Yetunde','Kemi','Bukola','Hauwa','Asmau','Ihuoma',
        'Obiageli','Toyin','Happiness','Grace','Mercy','Patience','Halima'
    ] AS names
),
surnames AS (
    SELECT ARRAY[
        'Okafor','Bello','Musa','Nwosu','Adeyemi','Ibrahim','Obi','Eze',
        'Etsu','Adebayo','Suleiman','Olatunji','Okonkwo','Adekunle','Onuoha',
        'Idris','Chukwu','Ogunleye','Olawale','Mohammed','Okeke','Ezealor',
        'Adeleke','Adewale','Ojo','Oyetunji','Oyeleke','Oyinlola','Oyeyemi','Okoro'
    ] AS names
),
gen AS (
    SELECT g,
           CASE (g % 2) WHEN 0 THEN 'M' ELSE 'F' END AS gender,
           (g % 8) + 1 AS dept_id
    FROM generate_series(1, 1000) AS g
)
INSERT INTO student (matric_no, full_name, gender, department_id, email, enrolled_on, status)
SELECT
    'SSU/' || d.department_code || '/2024/' || lpad(g.g::text, 3, '0'),
    CASE (g.g % 2)
        WHEN 0 THEN m.names[(g.g % 30) + 1]
        ELSE        f.names[(g.g % 30) + 1]
    END || ' ' || s.names[((g.g + 7) % 30) + 1],
    g.gender,
    g.dept_id,
    'bulk' || g.g || '@student.ststephen.edu.ng',
    DATE '2024-09-01',
    'ACTIVE'
FROM gen g
CROSS JOIN male_names m
CROSS JOIN female_names f
CROSS JOIN surnames s
JOIN department d ON d.department_id = g.dept_id
ON CONFLICT (matric_no) DO NOTHING;

-- =====================================================================
-- 2. 96 new courses (course_id 13..108) spread across departments.
-- =====================================================================
INSERT INTO course (course_code, course_title, credit_units, department_id, level)
SELECT
    'BU' || lpad(g::text, 3, '0'),
    'Bulk Course ' || g || ' — Department ' || ((g % 8) + 1),
    (g % 3 + 2)::smallint,
    (g % 8) + 1,
    ((g % 4) * 100 + 100)::smallint
FROM generate_series(1, 96) AS g
ON CONFLICT (course_code) DO NOTHING;

-- =====================================================================
-- 3. 500 course offerings — no lecturer clashes, no (course, sem, year)
--    duplicates, dates spread over the past ~1 year plus next 7 days.
--
--    Decomposition of g (0..499):
--      lecturer_id = (g / 42) + 1            → 1..12
--      slot_day    = ((g / 6) % 7) + 1       → 1..7
--      time_slot   = g % 6                   → 0..5 (12:00 to 17:00, 1-hour slots, after the 08:00-12:00 seed slots)
--      course_id   = (g / 9) + 13            → 13..68  (56 distinct bulk courses)
--      semester    = CASE (g % 3) …
--      year_idx    = (g / 3) % 3             → 2023/24, 2024/25, 2025/26
--    (course, semester, year) is unique per g; (lecturer, slot_day, time_slot)
--    is unique per g — so neither the UNIQUE constraint nor the clash
--    trigger fires.
-- =====================================================================
INSERT INTO course_offering
    (course_id, lecturer_id, semester, academic_year, capacity, offering_date,
     slot_day, start_time, end_time)
SELECT
    (g / 9) + 13,
    (g / 42) + 1,
    CASE (g % 3) WHEN 0 THEN 'FIRST' WHEN 1 THEN 'SECOND' ELSE 'SUMMER' END,
    CASE ((g / 3) % 3)
        WHEN 0 THEN '2023/2024'
        WHEN 1 THEN '2024/2025'
        ELSE        '2025/2026'
    END,
    (80 + (g % 80))::smallint,                               -- capacity 80..159
    (CURRENT_DATE - (g % 365) + 7),                          -- ~1yr back to +7 days
    ((g / 6) % 7) + 1::smallint,
    '12:00'::time + (g % 6) * make_interval(0, 0, 0, 0, 1, 0),
    '13:00'::time + (g % 6) * make_interval(0, 0, 0, 0, 1, 0)
FROM generate_series(0, 499) AS g
ON CONFLICT (course_id, semester, academic_year) DO NOTHING;

-- =====================================================================
-- 4. Exams for every bulk offering: one CA, one MIDSEM, one FINAL.
--    exam_date is in the future (>= today + 30), so the
--    trg_no_past_exam_date trigger never fires.
-- =====================================================================
INSERT INTO exam (offering_id, exam_type, exam_date, max_score)
SELECT o.offering_id, e.exam_type,
       CURRENT_DATE + e.offset_days,
       e.max_score::smallint
FROM course_offering o
CROSS JOIN (VALUES
    ('CA',     14, 20),
    ('MIDSEM', 28, 30),
    ('FINAL',  56, 70)
) AS e(exam_type, offset_days, max_score)
WHERE o.course_id >= 13                            -- only bulk offerings
ON CONFLICT (offering_id, exam_type) DO NOTHING;

-- =====================================================================
-- 5. Registrations — one row per "slot" of each offering's capacity.
--    Within an offering, idx 0..(capacity-1) maps to distinct students
--    via (rn*31 + idx) % 1020 + 1, so the partial UNIQUE index never
--    fires. Roughly 86% ACTIVE, 10% DROPPED, 4% COMPLETED — the
--    capacity trigger (WHEN NEW.status='ACTIVE') always sees count <
--    capacity.
--
--    registered_at = offering_date + (idx % 14) days → ranges from one
--    year back to ~20 days in the future (history plus next 14 days,
--    with some future registrations).
-- =====================================================================
INSERT INTO registration (student_id, offering_id, registered_at, status)
SELECT
    ((oc.rn * 31 + s.idx) % 1020) + 1,
    oc.offering_id,
    (oc.offering_date + (s.idx % 14))::timestamp
        + make_interval(0, 0, 0, 0, (s.idx % 12), (s.idx % 50), 0),
    CASE
        WHEN s.idx % 10 = 0 THEN 'DROPPED'
        WHEN s.idx % 25 = 0 THEN 'COMPLETED'
        ELSE                        'ACTIVE'
    END
FROM (
    SELECT offering_id, capacity, offering_date,
           row_number() OVER (ORDER BY offering_id) - 1 AS rn
    FROM course_offering
    WHERE course_id >= 13
) oc
CROSS JOIN LATERAL generate_series(0, oc.capacity - 1) AS s(idx)
ON CONFLICT (student_id, offering_id) WHERE status = 'ACTIVE' DO NOTHING;

-- =====================================================================
-- 6. Results — one FINAL-exam result for ~50% of ACTIVE registrations.
--    The result trigger's lookup is an index scan on registration.student_id
--    + exam.exam_id, so 30k rows insert in a few seconds. ON CONFLICT
--    guards against accidental (exam_id, student_id) dupes.
-- =====================================================================
INSERT INTO result (exam_id, student_id, score, graded_at)
SELECT
    e.exam_id,
    r.student_id,
    (40 + (random() * 60))::numeric(5,2),
    r.registered_at + make_interval(0, 0, 0, (30 + (random() * 60)::int), 0, 0, 0)
FROM registration r
JOIN exam e ON e.offering_id = r.offering_id AND e.exam_type = 'FINAL'
WHERE r.status = 'ACTIVE'
  AND (r.registration_id % 2 = 0)
ON CONFLICT (exam_id, student_id) DO NOTHING;

-- =====================================================================
-- 7. Fee payments in Naira, one per existing student for 2024/2025.
--    Tuition per faculty (NGN):
--      Science 850,000   Engineering 1,100,000   Management 750,000   Arts 700,000
-- =====================================================================
INSERT INTO fee_payment (student_id, amount_naira, paid_on, session, method)
SELECT
    s.student_id,
    CASE d.faculty_id
        WHEN 1 THEN 850000.00
        WHEN 2 THEN 1100000.00
        WHEN 3 THEN 750000.00
        WHEN 4 THEN 700000.00
        ELSE        800000.00
    END::numeric(12,2),
    DATE '2024-09-15' + (s.student_id % 30),
    '2024/2025',
    CASE (s.student_id % 4)
        WHEN 0 THEN 'CARD'
        WHEN 1 THEN 'BANK_TRANSFER'
        WHEN 2 THEN 'USSD'
        ELSE        'CASH'
    END
FROM student s
JOIN department d ON s.department_id = d.department_id
WHERE NOT EXISTS (
    SELECT 1 FROM fee_payment fp
     WHERE fp.student_id = s.student_id AND fp.session = '2024/2025'
)
ON CONFLICT DO NOTHING;

-- =====================================================================
-- 8. Sanity report: print the row counts so the student can confirm the
--    bulk load landed.
-- =====================================================================
SELECT '04_bulk_data.sql loaded OK' AS message;

SELECT 'faculties'      AS table_name, count(*) AS rows FROM faculty
UNION ALL SELECT 'departments',  count(*) FROM department
UNION ALL SELECT 'lecturers',    count(*) FROM lecturer
UNION ALL SELECT 'students',     count(*) FROM student
UNION ALL SELECT 'courses',      count(*) FROM course
UNION ALL SELECT 'offerings',    count(*) FROM course_offering
UNION ALL SELECT 'exams',        count(*) FROM exam
UNION ALL SELECT 'registrations',count(*) FROM registration
UNION ALL SELECT 'results',      count(*) FROM result
UNION ALL SELECT 'fee_payments', count(*) FROM fee_payment
ORDER BY table_name;
