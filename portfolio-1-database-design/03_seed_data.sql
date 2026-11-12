-- 03_seed_data.sql
-- Small realistic seed for St. Stephen Private University (Enugu, Nigeria).
-- Inserts 4 faculties, 8 departments, 12 lecturers, 20 students, 12 courses,
-- 8 course offerings, exams, registrations, results and fee payments.
-- Tuition figures are in Naira (NGN). All names are gender-matched
-- Nigerian names; no "Student 1" style placeholders.
--
-- Idempotent: every INSERT uses ON CONFLICT DO NOTHING, so the file is
-- safe to re-run.
--
-- Runs top to bottom with:  psql -d ststephen -v ON_ERROR_STOP=1 -f 03_seed_data.sql

\set ON_ERROR_STOP on
SET timezone TO 'Africa/Lagos';

-- =====================================================================
-- Faculties
-- =====================================================================
INSERT INTO faculty (faculty_code, faculty_name, dean_name) VALUES
    ('SCI', 'Faculty of Science',              'Prof. Ngozi Eze'),
    ('ENG', 'Faculty of Engineering',          'Prof. Sani Musa'),
    ('MGT', 'Faculty of Management Sciences',  'Prof. Bisi Adeyemi'),
    ('ART', 'Faculty of Arts',                 'Prof. Emeka Nwosu')
ON CONFLICT (faculty_code) DO NOTHING;

-- =====================================================================
-- Departments (department codes are unique across the university)
-- =====================================================================
INSERT INTO department (department_code, department_name, faculty_id, hod_name) VALUES
    ('CSC', 'Computer Science',         1, 'Dr. Chinedu Okafor'),
    ('PHY', 'Physics',                  1, 'Dr. Folake Adeyemi'),
    ('CIV', 'Civil Engineering',        2, 'Dr. Tunde Bello'),
    ('ELE', 'Electrical Engineering',   2, 'Dr. Aisha Bello'),
    ('ACC', 'Accounting',               3, 'Dr. Chioma Obi'),
    ('BUS', 'Business Administration',  3, 'Dr. Yakubu Etsu'),
    ('MCO', 'Mass Communication',       4, 'Dr. Adaeze Nwosu'),
    ('ENG', 'English and Literary Studies', 4, 'Dr. Sadiq Bello')
ON CONFLICT (department_code) DO NOTHING;

-- =====================================================================
-- Lecturers (gender-matched Nigerian names)
-- =====================================================================
INSERT INTO lecturer (staff_no, full_name, gender, department_id, email, hired_on) VALUES
    ('SSU/SCI/CSC/001', 'Dr. Chinedu Okafor',     'M', 1, 'chinedu.okafor@ststephen.edu.ng',   DATE '2018-09-01'),
    ('SSU/SCI/CSC/002', 'Dr. Ngozi Eze',          'F', 1, 'ngozi.eze@ststephen.edu.ng',        DATE '2017-09-01'),
    ('SSU/SCI/PHY/003', 'Dr. Folake Adeyemi',     'F', 2, 'folake.adeyemi@ststephen.edu.ng',   DATE '2019-09-01'),
    ('SSU/SCI/PHY/004', 'Dr. Adamu Ibrahim',      'M', 2, 'adamu.ibrahim@ststephen.edu.ng',    DATE '2020-09-01'),
    ('SSU/ENG/CIV/005', 'Dr. Tunde Bello',        'M', 3, 'tunde.bello@ststephen.edu.ng',      DATE '2016-09-01'),
    ('SSU/ENG/ELE/006', 'Dr. Aisha Bello',        'F', 4, 'aisha.bello@ststephen.edu.ng',      DATE '2018-09-01'),
    ('SSU/ENG/ELE/007', 'Engr. Emeka Nwosu',      'M', 4, 'emeka.nwosu@ststephen.edu.ng',      DATE '2021-09-01'),
    ('SSU/MGT/ACC/008', 'Dr. Chioma Obi',         'F', 5, 'chioma.obi@ststephen.edu.ng',       DATE '2019-09-01'),
    ('SSU/MGT/ACC/009', 'Dr. Bola Adebayo',       'M', 5, 'bola.adebayo@ststephen.edu.ng',     DATE '2020-09-01'),
    ('SSU/MGT/BUS/010', 'Dr. Yakubu Etsu',        'M', 6, 'yakubu.etsu@ststephen.edu.ng',      DATE '2018-09-01'),
    ('SSU/ART/MCO/011', 'Dr. Adaeze Nwosu',       'F', 7, 'adaeze.nwosu@ststephen.edu.ng',     DATE '2019-09-01'),
    ('SSU/ART/ENG/012', 'Dr. Sadiq Bello',        'M', 8, 'sadiq.bello@ststephen.edu.ng',      DATE '2017-09-01')
ON CONFLICT (staff_no) DO NOTHING;

-- =====================================================================
-- Students (gender-matched Nigerian names)
-- =====================================================================
INSERT INTO student (matric_no, full_name, gender, department_id, email, enrolled_on, status) VALUES
    ('SSU/CSC/2022/001', 'Tunde Adeyemi',         'M', 1, 'tunde.adeyemi@student.ststephen.edu.ng',   DATE '2022-09-01', 'ACTIVE'),
    ('SSU/CSC/2022/002', 'Chinedu Obi',           'M', 1, 'chinedu.obi@student.ststephen.edu.ng',     DATE '2022-09-01', 'ACTIVE'),
    ('SSU/CSC/2022/003', 'Ngozi Okafor',          'F', 1, 'ngozi.okafor@student.ststephen.edu.ng',    DATE '2022-09-01', 'ACTIVE'),
    ('SSU/CSC/2022/004', 'Adaeze Eze',            'F', 1, 'adaeze.eze@student.ststephen.edu.ng',      DATE '2022-09-01', 'ACTIVE'),
    ('SSU/CSC/2023/005', 'Musa Ibrahim',          'M', 1, 'musa.ibrahim@student.ststephen.edu.ng',    DATE '2023-09-01', 'ACTIVE'),
    ('SSU/PHY/2022/006', 'Aisha Bello',           'F', 2, 'aisha.bello.2@student.ststephen.edu.ng',   DATE '2022-09-01', 'ACTIVE'),
    ('SSU/PHY/2023/007', 'Sani Musa',             'M', 2, 'sani.musa@student.ststephen.edu.ng',       DATE '2023-09-01', 'ACTIVE'),
    ('SSU/CIV/2022/008', 'Emeka Nwosu',           'M', 3, 'emeka.nwosu.2@student.ststephen.edu.ng',   DATE '2022-09-01', 'ACTIVE'),
    ('SSU/CIV/2022/009', 'Folake Bello',          'F', 3, 'folake.bello.2@student.ststephen.edu.ng',  DATE '2022-09-01', 'ACTIVE'),
    ('SSU/ELE/2022/010', 'Chioma Eze',            'F', 4, 'chioma.eze.2@student.ststephen.edu.ng',    DATE '2022-09-01', 'ACTIVE'),
    ('SSU/ELE/2023/011', 'Bola Adebayo',          'M', 4, 'bola.adebayo.2@student.ststephen.edu.ng',  DATE '2023-09-01', 'ACTIVE'),
    ('SSU/ACC/2022/012', 'Yakubu Etsu',           'M', 5, 'yakubu.etsu.2@student.ststephen.edu.ng',   DATE '2022-09-01', 'ACTIVE'),
    ('SSU/ACC/2022/013', 'Bisi Adeyemi',          'F', 5, 'bisi.adeyemi@student.ststephen.edu.ng',    DATE '2022-09-01', 'ACTIVE'),
    ('SSU/ACC/2023/014', 'Chuka Eze',             'M', 5, 'chuka.eze@student.ststephen.edu.ng',       DATE '2023-09-01', 'ACTIVE'),
    ('SSU/BUS/2022/015', 'Halima Bello',          'F', 6, 'halima.bello@student.ststephen.edu.ng',    DATE '2022-09-01', 'ACTIVE'),
    ('SSU/BUS/2023/016', 'Tobias Okonkwo',        'M', 6, 'tobias.okonkwo@student.ststephen.edu.ng',  DATE '2023-09-01', 'ACTIVE'),
    ('SSU/MCO/2022/017', 'Zainab Suleiman',       'F', 7, 'zainab.suleiman@student.ststephen.edu.ng', DATE '2022-09-01', 'ACTIVE'),
    ('SSU/MCO/2023/018', 'Daniel Olatunji',       'M', 7, 'daniel.olatunji@student.ststephen.edu.ng', DATE '2023-09-01', 'ACTIVE'),
    ('SSU/ENG/2022/019', 'Amarachi Obi',          'F', 8, 'amarachi.obi@student.ststephen.edu.ng',    DATE '2022-09-01', 'ACTIVE'),
    ('SSU/ENG/2023/020', 'Samuel Adekunle',       'M', 8, 'samuel.adekunle@student.ststephen.edu.ng', DATE '2023-09-01', 'ACTIVE')
ON CONFLICT (matric_no) DO NOTHING;

-- =====================================================================
-- Courses (credit units, level per Nigerian university conventions)
-- =====================================================================
INSERT INTO course (course_code, course_title, credit_units, department_id, level) VALUES
    ('CSC101', 'Introduction to Computer Science', 3, 1, 100),
    ('CSC201', 'Data Structures and Algorithms',   3, 1, 200),
    ('CSC301', 'Database Systems',                 3, 1, 300),
    ('CSC401', 'Software Engineering',             4, 1, 400),
    ('PHY101', 'General Mechanics',                3, 2, 100),
    ('PHY201', 'Electromagnetism',                 3, 2, 200),
    ('CIV101', 'Engineering Mechanics',            3, 3, 100),
    ('ELE101', 'Circuit Analysis I',               3, 4, 100),
    ('ACC101', 'Financial Accounting I',           3, 5, 100),
    ('BUS101', 'Principles of Management',         2, 6, 100),
    ('MCO101', 'Introduction to Mass Media',       3, 7, 100),
    ('ENG101', 'Introduction to Literature',       3, 8, 100)
ON CONFLICT (course_code) DO NOTHING;

-- =====================================================================
-- Course offerings (FIRST semester of the current academic year)
--   offering_date is relative to today so the seed data is always live.
--   Slot days: 1=Mon … 5=Fri; times chosen to avoid lecturer clashes.
-- =====================================================================
INSERT INTO course_offering
    (course_id, lecturer_id, semester, academic_year, capacity, offering_date, slot_day, start_time, end_time)
SELECT v.course_id, v.lecturer_id, v.semester, v.academic_year,
       v.capacity::smallint, CURRENT_DATE + 7, v.slot_day::smallint, v.start_time::time, v.end_time::time
FROM (VALUES
    (1,  1, 'FIRST', '2025/2026', 60, 1, '08:00', '10:00'),
    (2,  2, 'FIRST', '2025/2026', 50, 1, '10:00', '12:00'),
    (3,  1, 'FIRST', '2025/2026', 40, 2, '08:00', '10:00'),
    (4,  2, 'FIRST', '2025/2026', 35, 2, '10:00', '12:00'),
    (5,  3, 'FIRST', '2025/2026', 45, 3, '08:00', '10:00'),
    (6,  4, 'FIRST', '2025/2026', 40, 3, '10:00', '12:00'),
    (7,  5, 'FIRST', '2025/2026', 50, 4, '08:00', '10:00'),
    (8,  6, 'FIRST', '2025/2026', 50, 4, '10:00', '12:00')
) AS v(course_id, lecturer_id, semester, academic_year, capacity, slot_day, start_time, end_time)
ON CONFLICT (course_id, semester, academic_year) DO NOTHING;

-- =====================================================================
-- Exams for each offering
-- =====================================================================
INSERT INTO exam (offering_id, exam_type, exam_date, max_score)
SELECT o.offering_id, e.exam_type,
       CURRENT_DATE + 30 + e.offset_days, e.max_score::smallint
FROM course_offering o
CROSS JOIN (VALUES
    ('CA',     7,  20),
    ('MIDSEM', 21, 30),
    ('FINAL',  60, 70)
) AS e(exam_type, offset_days, max_score)
ON CONFLICT (offering_id, exam_type) DO NOTHING;

-- =====================================================================
-- Registrations (a handful, all ACTIVE)
--   Covers offerings 1..8 with a few students each.
-- =====================================================================
INSERT INTO registration (student_id, offering_id, registered_at, status)
SELECT v.student_id, v.offering_id, now() - (v.age_days || ' days')::interval, v.status
FROM (VALUES
    (1, 1,  3, 'ACTIVE'),
    (2, 1,  3, 'ACTIVE'),
    (3, 1,  4, 'ACTIVE'),
    (4, 1,  5, 'ACTIVE'),
    (1, 2,  5, 'ACTIVE'),
    (2, 2,  5, 'ACTIVE'),
    (3, 3,  6, 'ACTIVE'),
    (4, 3,  6, 'ACTIVE'),
    (5, 3,  7, 'ACTIVE'),
    (6, 5,  8, 'ACTIVE'),
    (7, 5,  8, 'ACTIVE'),
    (8, 7,  9, 'ACTIVE'),
    (9, 7,  9, 'ACTIVE'),
    (10, 8, 10, 'ACTIVE'),
    (11, 8, 10, 'ACTIVE')
) AS v(student_id, offering_id, age_days, status)
ON CONFLICT DO NOTHING;

-- =====================================================================
-- Results for the CA exam on offering 1 (the only past exam we fabricate
-- explicitly; bulk data produces the rest). For seed data, we need a
-- 'past' exam_date that satisfies trg_no_past_exam_date. We do this by
-- inserting a separate CA exam row for an offering whose exam_date we
-- back-date inside an exception-safe DO block. This is only here so the
-- sample has a few graded rows; bulk data is the main source.
-- =====================================================================
DO $$
DECLARE
    v_offering INT;
    v_exam     INT;
BEGIN
    SELECT offering_id INTO v_offering
      FROM course_offering
     WHERE course_id = 1 AND semester = 'FIRST' AND academic_year = '2025/2026'
     LIMIT 1;

    -- Use the CA exam that already exists (date = today + 37). The trigger
    -- only blocks PAST dates, so this is fine.
    SELECT exam_id INTO v_exam FROM exam WHERE offering_id = v_offering AND exam_type = 'CA';

    INSERT INTO result (exam_id, student_id, score, graded_at)
    SELECT v_exam, s.student_id,
           (40 + (random()*60))::numeric(5,2),
           now() - (random() * 5) * interval '1 day'
      FROM student s
     WHERE s.student_id IN (1,2,3,4)
    ON CONFLICT (exam_id, student_id) DO NOTHING;
END $$;

-- =====================================================================
-- Fee payments (Naira). Tuition per session for Science is about
-- NGN 850,000; Engineering NGN 1,100,000; Management NGN 750,000; Arts
-- NGN 700,000.
-- =====================================================================
INSERT INTO fee_payment (student_id, amount_naira, paid_on, session, method)
SELECT v.student_id, v.amount::numeric(12,2),
       CURRENT_DATE - v.age_days::int, v.session, v.method
FROM (VALUES
    (1,  850000.00, 30, '2025/2026', 'BANK_TRANSFER'),
    (2,  850000.00, 30, '2025/2026', 'BANK_TRANSFER'),
    (3,  850000.00, 29, '2025/2026', 'CARD'),
    (4,  850000.00, 28, '2025/2026', 'USSD'),
    (5,  850000.00, 27, '2025/2026', 'BANK_TRANSFER'),
    (6,  850000.00, 26, '2025/2026', 'CARD'),
    (7,  850000.00, 25, '2025/2026', 'BANK_TRANSFER'),
    (8, 1100000.00, 24, '2025/2026', 'BANK_TRANSFER'),
    (9, 1100000.00, 24, '2025/2026', 'CARD'),
    (10, 1100000.00, 23, '2025/2026', 'BANK_TRANSFER'),
    (11, 1100000.00, 22, '2025/2026', 'BANK_TRANSFER'),
    (12, 750000.00, 21, '2025/2026', 'CARD'),
    (13, 750000.00, 21, '2025/2026', 'BANK_TRANSFER'),
    (14, 750000.00, 20, '2025/2026', 'USSD'),
    (15, 750000.00, 20, '2025/2026', 'BANK_TRANSFER'),
    (16, 750000.00, 19, '2025/2026', 'BANK_TRANSFER'),
    (17, 700000.00, 18, '2025/2026', 'CARD'),
    (18, 700000.00, 18, '2025/2026', 'BANK_TRANSFER'),
    (19, 700000.00, 17, '2025/2026', 'BANK_TRANSFER'),
    (20, 700000.00, 17, '2025/2026', 'CARD')
) AS v(student_id, amount, age_days, session, method)
ON CONFLICT DO NOTHING;

SELECT '03_seed_data.sql loaded OK' AS message;
