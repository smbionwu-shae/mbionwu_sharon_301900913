#!/usr/bin/env python3
"""
race_demos.py — Concurrency demonstrations for St. Stephen USMS.

Six labelled parts, two real psycopg2 sessions running in Python threads:

  1. THE BUG        — no lock, two students take the last place
                      (capacity trigger races under READ COMMITTED).
  2. CONSTRAINT FIX — a counter row + CHECK constraint serialises the
                      registration on the offering row.
  3. ADVISORY LOCK  — pg_advisory_xact_lock(offering_id) serialises the
                      transactions explicitly.
  4. SERIALIZABLE   — both transactions at SERIALIZABLE; one is aborted
                      with SQLSTATE 40001 (serialization_failure).
  5. READ COMMITTED vs REPEATABLE READ — same scenario, two isolation
                      levels, different snapshots.
  6. DEADLOCK       — two transactions update rows in opposite orders;
                      PostgreSQL detects SQLSTATE 40P01 (deadlock_detected).
                      The fixed-order version then runs without a deadlock.

The script creates its own demo rows (faculty RDF, dept RDFT, lecturer,
course, two students, several offerings and a small helper table) and
deletes them at the end so the database is left clean. There are no
pg_sleep tricks that need hand-pasting and no psql <<SQL two-terminal
demos.

Run with:  python3 race_demos.py
"""

import os
import sys
import threading
import traceback
from threading import Barrier, Thread

try:
    import psycopg2
    from psycopg2 import extensions as pg_ext
except ImportError:
    print("ERROR: psycopg2 not installed. Run:  pip install psycopg2-binary")
    sys.exit(1)


# ----------------------------------------------------------------------
# Connection config: Unix socket, no password (GitHub Codespaces).
# ----------------------------------------------------------------------
DB_DSN = "dbname=ststephen"

ISOL_RC = pg_ext.ISOLATION_LEVEL_READ_COMMITTED
ISOL_RR = pg_ext.ISOLATION_LEVEL_REPEATABLE_READ
ISOL_SR = pg_ext.ISOLATION_LEVEL_SERIALIZABLE

HR = "=" * 70


def log(msg):
    print(msg, flush=True)


def connect():
    conn = psycopg2.connect(DB_DSN)
    conn.autocommit = False
    return conn


def set_iso(conn, level):
    conn.set_session(isolation_level=level)


# ----------------------------------------------------------------------
# Demo scaffolding: create / delete the rows used by every part.
# ----------------------------------------------------------------------
def setup_demo_rows():
    """Create the persistent demo entities used by all parts."""
    with connect() as conn:
        with conn.cursor() as cur:
            cur.execute("SET timezone TO 'Africa/Lagos';")
            cur.execute("""
                INSERT INTO faculty (faculty_code, faculty_name, dean_name)
                VALUES ('RDF', 'Race Demo Faculty', 'Prof. Race Demo')
                ON CONFLICT (faculty_code) DO NOTHING;
            """)
            cur.execute("""
                INSERT INTO department (department_code, department_name, faculty_id, hod_name)
                VALUES ('RDFT', 'Race Demo Dept',
                        (SELECT faculty_id FROM faculty WHERE faculty_code='RDF'),
                        'Dr. Race HOD')
                ON CONFLICT (department_code) DO NOTHING;
            """)
            cur.execute("""
                INSERT INTO lecturer (staff_no, full_name, gender, department_id, email, hired_on)
                VALUES ('RDF/L001', 'Dr. Race Lecturer', 'M',
                        (SELECT department_id FROM department WHERE department_code='RDFT'),
                        'race.lecturer@ststephen.edu.ng', CURRENT_DATE)
                ON CONFLICT (staff_no) DO NOTHING;
            """)
            cur.execute("""
                INSERT INTO course (course_code, course_title, credit_units, department_id, level)
                VALUES ('RDFC01', 'Race Demo Course', 3,
                        (SELECT department_id FROM department WHERE department_code='RDFT'), 300)
                ON CONFLICT (course_code) DO NOTHING;
            """)
            students = [
                ('RDF/S/001', 'Adaeze Race', 'F'),
                ('RDF/S/002', 'Bola Race',   'M'),
            ]
            for matric, name, gender in students:
                cur.execute("""
                    INSERT INTO student (matric_no, full_name, gender, department_id, email, enrolled_on, status)
                    VALUES (%s, %s, %s,
                        (SELECT department_id FROM department WHERE department_code='RDFT'),
                        %s, CURRENT_DATE, 'ACTIVE')
                    ON CONFLICT (matric_no) DO NOTHING;
                """, (matric, name, gender,
                      matric.lower().replace('/', '.') + '@ststephen.edu.ng'))
        conn.commit()


_SLOT = [0]


def make_offering(semester, year, capacity, slot_day=3, start='12:00', end='14:00'):
    """Insert a fresh offering; return its offering_id.
    Each call gets its own weekday so the demo lecturer never clashes."""
    _SLOT[0] += 1
    slot_day = _SLOT[0]
    with connect() as conn:
        with conn.cursor() as cur:
            cur.execute("SET timezone TO 'Africa/Lagos';")
            cur.execute("""
                INSERT INTO course_offering
                    (course_id, lecturer_id, semester, academic_year, capacity,
                     offering_date, slot_day, start_time, end_time)
                SELECT c.course_id, l.lecturer_id, %s, %s, %s,
                       CURRENT_DATE + 7, %s, %s, %s
                FROM course c, lecturer l
                WHERE c.course_code='RDFC01' AND l.staff_no='RDF/L001'
                RETURNING offering_id;
            """, (semester, year, capacity, slot_day, start, end))
            row = cur.fetchone()
        conn.commit()
        return row[0] if row else None


def get_student_id(matric):
    with connect() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT student_id FROM student WHERE matric_no=%s", (matric,))
            r = cur.fetchone()
            return r[0] if r else None


def count_active(offering_id):
    with connect() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT count(*) FROM registration WHERE offering_id=%s AND status='ACTIVE'",
                (offering_id,))
            return cur.fetchone()[0]


def clear_offering_registrations(offering_id):
    """Delete any demo registrations on an offering (used between parts)."""
    with connect() as conn:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM registration WHERE offering_id=%s", (offering_id,))
        conn.commit()


def drop_helper_tables():
    with connect() as conn:
        with conn.cursor() as cur:
            cur.execute("DROP TABLE IF EXISTS race_demo_capacity;")
            cur.execute("DROP TABLE IF EXISTS race_demo_counter;")
            cur.execute("DROP TABLE IF EXISTS race_demo_deadlock;")
        conn.commit()


def cleanup():
    """Delete everything race_demos.py created."""
    with connect() as conn:
        with conn.cursor() as cur:
            cur.execute("SET timezone TO 'Africa/Lagos';")
            # Drop helper tables first (they may FK to course_offering).
            cur.execute("DROP TABLE IF EXISTS race_demo_capacity;")
            cur.execute("DROP TABLE IF EXISTS race_demo_counter;")
            cur.execute("DROP TABLE IF EXISTS race_demo_deadlock;")
            cur.execute("""
                DELETE FROM result
                 WHERE exam_id IN (
                     SELECT e.exam_id FROM exam e
                     JOIN course_offering o ON o.offering_id=e.offering_id
                     JOIN course c ON c.course_id=o.course_id
                     WHERE c.course_code='RDFC01');
            """)
            cur.execute("""
                DELETE FROM registration
                 WHERE offering_id IN (
                     SELECT o.offering_id FROM course_offering o
                     JOIN course c ON c.course_id=o.course_id
                     WHERE c.course_code='RDFC01');
            """)
            cur.execute("""
                DELETE FROM exam
                 WHERE offering_id IN (
                     SELECT o.offering_id FROM course_offering o
                     JOIN course c ON c.course_id=o.course_id
                     WHERE c.course_code='RDFC01');
            """)
            cur.execute("""
                DELETE FROM course_offering
                 WHERE course_id = (SELECT course_id FROM course WHERE course_code='RDFC01');
            """)
            cur.execute("DELETE FROM student WHERE matric_no LIKE 'RDF/S/%';")
            cur.execute("DELETE FROM course WHERE course_code='RDFC01';")
            cur.execute("DELETE FROM lecturer WHERE staff_no='RDF/L001';")
            cur.execute("DELETE FROM department WHERE department_code='RDFT';")
            cur.execute("DELETE FROM faculty WHERE faculty_code='RDF';")
        conn.commit()


# ======================================================================
# PART 1 — The bug (no lock; two students take the last place)
# ======================================================================
def part_1_bug():
    log(HR)
    log("PART 1 — THE BUG (no lock, two students take the last place)")
    log(HR)
    oid = make_offering('FIRST', '2024/2025', 1)              # capacity = 1
    s1 = get_student_id('RDF/S/001')
    s2 = get_student_id('RDF/S/002')
    log(f"  offering_id={oid}  capacity=1  student_A={s1}  student_B={s2}")

    results = {}
    barrier = Barrier(2)

    def worker(label, sid):
        try:
            conn = connect(); set_iso(conn, ISOL_RC)
            cur = conn.cursor()
            cur.execute("BEGIN")
            barrier.wait()                  # both threads start INSERT together
            cur.execute("""
                INSERT INTO registration (student_id, offering_id, status)
                VALUES (%s, %s, 'ACTIVE')
            """, (sid, oid))
            conn.commit()
            results[label] = ("COMMITTED", None)
        except psycopg2.Error as e:
            try: conn.rollback()
            except Exception: pass
            results[label] = ("FAILED", e.pgcode, str(e).strip()[:120])
        finally:
            try: conn.close()
            except Exception: pass

    t1 = Thread(target=worker, args=("T1", s1))
    t2 = Thread(target=worker, args=("T2", s2))
    t1.start(); t2.start(); t1.join(); t2.join()

    active = count_active(oid)
    log(f"  T1 outcome: {results.get('T1')}")
    log(f"  T2 outcome: {results.get('T2')}")
    log(f"  Active rows after = {active}  (capacity = 1)")
    if active > 1:
        log("  >>> BUG REPRODUCED: capacity=1 but two ACTIVE rows committed.")
    else:
        log("  >>> Bug did not reproduce this run (re-run if needed).")

    # Clean up this part's data so Part 2 starts fresh.
    clear_offering_registrations(oid)


# ======================================================================
# PART 2 — UNIQUE / constraint fix (counter row + CHECK)
# ======================================================================
def part_2_constraint_fix():
    log(HR)
    log("PART 2 — CONSTRAINT FIX (counter row + CHECK(active_count <= capacity))")
    log(HR)

    # Helper table that maintains an atomic active_count per offering.
    with connect() as conn:
        with conn.cursor() as cur:
            cur.execute("SET timezone TO 'Africa/Lagos';")
            cur.execute("""
                CREATE TABLE IF NOT EXISTS race_demo_capacity (
                    offering_id   INTEGER PRIMARY KEY
                                  REFERENCES course_offering(offering_id) ON DELETE CASCADE,
                    capacity      SMALLINT NOT NULL,
                    active_count  SMALLINT NOT NULL DEFAULT 0,
                    CHECK (active_count >= 0 AND active_count <= capacity)
                );
            """)
        conn.commit()

    oid = make_offering('SECOND', '2024/2025', 1)
    s1 = get_student_id('RDF/S/001')
    s2 = get_student_id('RDF/S/002')
    log(f"  offering_id={oid}  capacity=1  student_A={s1}  student_B={s2}")

    # Seed the counter row.
    with connect() as conn:
        with conn.cursor() as cur:
            cur.execute("SET timezone TO 'Africa/Lagos';")
            cur.execute("""
                INSERT INTO race_demo_capacity (offering_id, capacity, active_count)
                VALUES (%s, 1, 0);
            """, (oid,))
        conn.commit()

    results = {}
    barrier = Barrier(2)

    def worker(label, sid):
        try:
            conn = connect(); set_iso(conn, ISOL_RC)
            cur = conn.cursor()
            cur.execute("BEGIN")
            barrier.wait()
            # The UPDATE on the same row serialises both transactions.
            # The CHECK constraint catches the second one's increment.
            cur.execute("""
                UPDATE race_demo_capacity
                   SET active_count = active_count + 1
                 WHERE offering_id = %s
            """, (oid,))
            cur.execute("""
                INSERT INTO registration (student_id, offering_id, status)
                VALUES (%s, %s, 'ACTIVE')
            """, (sid, oid))
            conn.commit()
            results[label] = ("COMMITTED", None)
        except psycopg2.Error as e:
            try: conn.rollback()
            except Exception: pass
            results[label] = ("FAILED", e.pgcode, str(e).strip()[:120])
        finally:
            try: conn.close()
            except Exception: pass

    t1 = Thread(target=worker, args=("T1", s1))
    t2 = Thread(target=worker, args=("T2", s2))
    t1.start(); t2.start(); t1.join(); t2.join()

    active = count_active(oid)
    log(f"  T1 outcome: {results.get('T1')}")
    log(f"  T2 outcome: {results.get('T2')}")
    log(f"  Active rows after = {active}  (capacity = 1)")
    if active == 1:
        log("  >>> FIX CONFIRMED: only one ACTIVE row landed.")
    else:
        log("  >>> Unexpected — investigate.")

    clear_offering_registrations(oid)


# ======================================================================
# PART 3 — Advisory lock fix (pg_advisory_xact_lock(offering_id))
# ======================================================================
def part_3_advisory_lock():
    log(HR)
    log("PART 3 — ADVISORY LOCK FIX (pg_advisory_xact_lock(offering_id))")
    log(HR)

    oid = make_offering('SUMMER', '2024/2025', 1)
    s1 = get_student_id('RDF/S/001')
    s2 = get_student_id('RDF/S/002')
    log(f"  offering_id={oid}  capacity=1  student_A={s1}  student_B={s2}")

    results = {}
    barrier = Barrier(2)

    def worker(label, sid):
        try:
            conn = connect(); set_iso(conn, ISOL_RC)
            cur = conn.cursor()
            cur.execute("BEGIN")
            barrier.wait()                          # both threads start together
            # Acquire the transaction-scoped advisory lock keyed on the
            # offering_id. Second transaction blocks here until the first
            # commits (which releases the xact lock).
            cur.execute("SELECT pg_advisory_xact_lock(%s)", (oid,))
            cur.fetchone()
            cur.execute("""
                INSERT INTO registration (student_id, offering_id, status)
                VALUES (%s, %s, 'ACTIVE')
            """, (sid, oid))
            conn.commit()
            results[label] = ("COMMITTED", None)
        except psycopg2.Error as e:
            try: conn.rollback()
            except Exception: pass
            results[label] = ("FAILED", e.pgcode, str(e).strip()[:120])
        finally:
            try: conn.close()
            except Exception: pass

    t1 = Thread(target=worker, args=("T1", s1))
    t2 = Thread(target=worker, args=("T2", s2))
    t1.start(); t2.start(); t1.join(); t2.join()

    active = count_active(oid)
    log(f"  T1 outcome: {results.get('T1')}")
    log(f"  T2 outcome: {results.get('T2')}")
    log(f"  Active rows after = {active}  (capacity = 1)")
    if active == 1:
        log("  >>> FIX CONFIRMED: only one ACTIVE row landed; the other was blocked.")
    else:
        log("  >>> Unexpected — investigate.")

    clear_offering_registrations(oid)


# ======================================================================
# PART 4 — SERIALIZABLE (expects SQLSTATE 40001)
# ======================================================================
def part_4_serializable():
    log(HR)
    log("PART 4 — SERIALIZABLE isolation (expects SQLSTATE 40001)")
    log(HR)

    oid = make_offering('FIRST', '2023/2024', 1)
    s1 = get_student_id('RDF/S/001')
    s2 = get_student_id('RDF/S/002')
    log(f"  offering_id={oid}  capacity=1  student_A={s1}  student_B={s2}")

    results = {}
    barrier = Barrier(2)

    def worker(label, sid):
        try:
            conn = connect(); set_iso(conn, ISOL_SR)
            cur = conn.cursor()
            cur.execute("BEGIN ISOLATION LEVEL SERIALIZABLE")
            barrier.wait()
            cur.execute("""
                INSERT INTO registration (student_id, offering_id, status)
                VALUES (%s, %s, 'ACTIVE')
            """, (sid, oid))
            conn.commit()
            results[label] = ("COMMITTED", None)
        except psycopg2.Error as e:
            try: conn.rollback()
            except Exception: pass
            results[label] = ("ABORTED", e.pgcode, str(e).strip()[:120])
        finally:
            try: conn.close()
            except Exception: pass

    t1 = Thread(target=worker, args=("T1", s1))
    t2 = Thread(target=worker, args=("T2", s2))
    t1.start(); t2.start(); t1.join(); t2.join()

    r1 = results.get("T1"); r2 = results.get("T2")
    log(f"  T1 outcome: {r1}")
    log(f"  T2 outcome: {r2}")
    expected = any((r and r[0] == "ABORTED" and r[1] == "40001") for r in (r1, r2))
    if expected:
        log("  >>> PASS: at least one transaction aborted with SQLSTATE 40001.")
    else:
        log("  >>> NOTE: 40001 did not fire this run (try re-running).")

    clear_offering_registrations(oid)


# ======================================================================
# PART 5 — READ COMMITTED vs REPEATABLE READ
# ======================================================================
def part_5_iso_levels():
    log(HR)
    log("PART 5 — READ COMMITTED vs REPEATABLE READ (snapshot behaviour)")
    log(HR)

    # Helper table: a single row whose value we can flip between reads.
    with connect() as conn:
        with conn.cursor() as cur:
            cur.execute("SET timezone TO 'Africa/Lagos';")
            cur.execute("""
                CREATE TABLE IF NOT EXISTS race_demo_counter (
                    id   INTEGER PRIMARY KEY,
                    val  INTEGER NOT NULL
                );
            """)
            cur.execute("DELETE FROM race_demo_counter;")
            cur.execute("INSERT INTO race_demo_counter (id, val) VALUES (1, 0);")
        conn.commit()

    # --- 5a. READ COMMITTED: same transaction sees fresh committed data. ---
    log("  5a. READ COMMITTED — a second read inside the same transaction")
    log("      sees another transaction's committed write.")
    reads_rc = []
    barrier = Barrier(2)
    writer_done = threading.Event()

    def reader_rc():
        try:
            conn = connect(); set_iso(conn, ISOL_RC)
            cur = conn.cursor()
            cur.execute("BEGIN")
            cur.execute("SELECT val FROM race_demo_counter WHERE id=1")
            reads_rc.append(("first_read", cur.fetchone()[0]))
            barrier.wait()                       # writer now updates + commits
            writer_done.wait(timeout=5)          # ensure writer committed before second read
            cur.execute("SELECT val FROM race_demo_counter WHERE id=1")
            reads_rc.append(("second_read", cur.fetchone()[0]))
            conn.commit()
        except Exception as e:
            traceback.print_exc()
        finally:
            try: conn.close()
            except Exception: pass

    def writer_rc():
        try:
            conn = connect(); set_iso(conn, ISOL_RC)
            cur = conn.cursor()
            cur.execute("BEGIN")
            barrier.wait()
            cur.execute("UPDATE race_demo_counter SET val = val + 1 WHERE id=1")
            conn.commit()
            writer_done.set()
        except Exception as e:
            traceback.print_exc()
        finally:
            try: conn.close()
            except Exception: pass

    tr = Thread(target=reader_rc); tw = Thread(target=writer_rc)
    tr.start(); tw.start(); tr.join(); tw.join()
    log(f"      READ COMMITTED reads: {reads_rc}")
    if reads_rc[0][1] != reads_rc[1][1]:
        log("      >>> PASS: READ COMMITTED saw the writer's committed value.")
    else:
        log("      >>> NOTE: READ COMMITTED did not see the update (re-run).")

    # Reset for 5b.
    with connect() as conn:
        with conn.cursor() as cur:
            cur.execute("UPDATE race_demo_counter SET val=0 WHERE id=1;")
        conn.commit()

    # --- 5b. REPEATABLE READ: same transaction uses one snapshot. ---
    log("  5b. REPEATABLE READ — a second read inside the same transaction")
    log("      uses the original snapshot (writer's update is invisible).")
    reads_rr = []
    barrier = Barrier(2)
    writer_done = threading.Event()

    def reader_rr():
        try:
            conn = connect(); set_iso(conn, ISOL_RR)
            cur = conn.cursor()
            cur.execute("BEGIN ISOLATION LEVEL REPEATABLE READ")
            cur.execute("SELECT val FROM race_demo_counter WHERE id=1")
            reads_rr.append(("first_read", cur.fetchone()[0]))
            barrier.wait()
            writer_done.wait(timeout=5)
            cur.execute("SELECT val FROM race_demo_counter WHERE id=1")
            reads_rr.append(("second_read", cur.fetchone()[0]))
            conn.commit()
        except Exception as e:
            traceback.print_exc()
        finally:
            try: conn.close()
            except Exception: pass

    def writer_rr():
        try:
            conn = connect(); set_iso(conn, ISOL_RC)
            cur = conn.cursor()
            cur.execute("BEGIN")
            barrier.wait()
            cur.execute("UPDATE race_demo_counter SET val = val + 1 WHERE id=1")
            conn.commit()
            writer_done.set()
        except Exception as e:
            traceback.print_exc()
        finally:
            try: conn.close()
            except Exception: pass

    tr = Thread(target=reader_rr); tw = Thread(target=writer_rr)
    tr.start(); tw.start(); tr.join(); tw.join()
    log(f"      REPEATABLE READ reads: {reads_rr}")
    if reads_rr[0][1] == reads_rr[1][1]:
        log("      >>> PASS: REPEATABLE READ kept the snapshot value.")
    else:
        log("      >>> NOTE: REPEATABLE READ saw a new value (re-run).")


# ======================================================================
# PART 6 — Deadlock (40P01) plus the fixed-order version
# ======================================================================
def part_6_deadlock():
    log(HR)
    log("PART 6 — DEADLOCK (40P01) and the fixed-order version")
    log(HR)

    with connect() as conn:
        with conn.cursor() as cur:
            cur.execute("SET timezone TO 'Africa/Lagos';")
            cur.execute("""
                CREATE TABLE IF NOT EXISTS race_demo_deadlock (
                    id  INTEGER PRIMARY KEY,
                    val INTEGER NOT NULL DEFAULT 0
                );
            """)
            cur.execute("DELETE FROM race_demo_deadlock;")
            cur.execute("INSERT INTO race_demo_deadlock (id) VALUES (1), (2);")
        conn.commit()

    # --- 6a. Buggy version: T1 updates 1→2, T2 updates 2→1 → deadlock. ---
    log("  6a. Buggy version — opposite update orders.")
    results = {}
    barrier = Barrier(2)

    def worker(label, first_id, second_id):
        try:
            conn = connect(); set_iso(conn, ISOL_RC)
            cur = conn.cursor()
            cur.execute("BEGIN")
            cur.execute("UPDATE race_demo_deadlock SET val=val+1 WHERE id=%s", (first_id,))
            barrier.wait()                   # both threads hold their first row
            cur.execute("UPDATE race_demo_deadlock SET val=val+1 WHERE id=%s", (second_id,))
            conn.commit()
            results[label] = ("COMMITTED", None)
        except psycopg2.Error as e:
            try: conn.rollback()
            except Exception: pass
            results[label] = ("ABORTED", e.pgcode, str(e).strip()[:120])
        finally:
            try: conn.close()
            except Exception: pass

    t1 = Thread(target=worker, args=("T1", 1, 2))   # 1 then 2
    t2 = Thread(target=worker, args=("T2", 2, 1))   # 2 then 1
    t1.start(); t2.start(); t1.join(); t2.join()
    log(f"      T1 outcome: {results.get('T1')}")
    log(f"      T2 outcome: {results.get('T2')}")
    expected = any((r and r[0] == "ABORTED" and r[1] == "40P01") for r in
                   (results.get("T1"), results.get("T2")))
    if expected:
        log("      >>> PASS: PostgreSQL detected the deadlock (SQLSTATE 40P01).")
    else:
        log("      >>> NOTE: no deadlock this run (re-run to reproduce).")

    # --- 6b. Fixed version: both threads update 1 then 2 → no deadlock. ---
    log("  6b. Fixed version — same update order on both threads.")
    results = {}
    barrier = Barrier(1)      # the second thread blocks on row 1, so it must not wait here

    t1 = Thread(target=worker, args=("T1", 1, 2))
    t2 = Thread(target=worker, args=("T2", 1, 2))
    t1.start(); t2.start(); t1.join(); t2.join()
    log(f"      T1 outcome: {results.get('T1')}")
    log(f"      T2 outcome: {results.get('T2')}")
    ok = all((r and r[0] == "COMMITTED") for r in (results.get("T1"), results.get("T2")))
    if ok:
        log("      >>> PASS: both transactions committed without a deadlock.")
    else:
        log("      >>> NOTE: at least one transaction failed (re-run).")


# ======================================================================
# main
# ======================================================================
def Hr():
    return HR


def main():
    log("race_demos.py — St. Stephen USMS concurrency demonstrations")
    log(f"DSN: {DB_DSN}")
    try:
        cleanup()          # re-runnable: remove leftovers from an earlier run
        setup_demo_rows()
        part_1_bug()
        part_2_constraint_fix()
        part_3_advisory_lock()
        part_4_serializable()
        part_5_iso_levels()
        part_6_deadlock()
    finally:
        try:
            cleanup()
            log(HR)
            log("CLEANUP — demo rows deleted; database left as it was.")
            log(HR)
        except Exception:
            traceback.print_exc()


if __name__ == "__main__":
    main()
