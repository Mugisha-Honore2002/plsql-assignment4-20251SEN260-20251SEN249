-- =====================================================================
-- test_success_cases.sql
-- Run AFTER schema, sample data, functions and procedures are in place.
-- Run top-to-bottom as a script (F5 in SQL Developer). Re-run
-- 00_schema/02_insert_sample_data.sql to reset the data first.
-- Take one screenshot per test (name: screenshots/<test_name>_output.png).
-- =====================================================================
SET SERVEROUTPUT ON SIZE UNLIMITED;

PROMPT ===== TEST 1 (test_register_success): register_student_course =====
-- Concepts: records, implicit INSERT cursor, OUT parameters
-- EXPECTED: "Jean Mukamana enrolled in CS101 for 2026-FALL (seat 1 of 40)."
DECLARE
  v_id  enrollments.enrollment_id%TYPE;
  v_msg VARCHAR2(400);
BEGIN
  register_student_course(1003, 101, '2026-FALL', v_id, v_msg);
  DBMS_OUTPUT.PUT_LINE('New enrollment_id = ' || v_id);
  DBMS_OUTPUT.PUT_LINE(v_msg);
END;
/

PROMPT ===== TEST 2 (test_update_grade_success): update_grade =====
-- Concepts: implicit UPDATE cursor, SQL%ROWCOUNT, audit trail
-- EXPECTED: "... none -> 84.5 (B), rows updated: 1" and one row in GRADE_AUDIT
DECLARE
  v_id     enrollments.enrollment_id%TYPE;
  v_letter enrollments.letter_grade%TYPE;
BEGIN
  SELECT enrollment_id INTO v_id
    FROM enrollments
   WHERE student_id = 1002 AND course_id = 105 AND semester = '2026-FALL';
  update_grade(v_id, 84.5, v_letter);
  DBMS_OUTPUT.PUT_LINE('Letter grade returned = ' || v_letter);
END;
/
SELECT audit_id, enrollment_id, old_score, new_score, changed_by FROM grade_audit;

PROMPT ===== TEST 3 (test_drop_enrollment_success): drop_enrollment =====
-- Concepts: implicit DELETE cursor, SQL%NOTFOUND / SQL%ROWCOUNT
-- EXPECTED: "Enrollment <id> dropped (1 row)."  (drops the row created in TEST 1)
DECLARE
  v_id   enrollments.enrollment_id%TYPE;
  v_rows PLS_INTEGER;
BEGIN
  SELECT enrollment_id INTO v_id
    FROM enrollments
   WHERE student_id = 1003 AND course_id = 101 AND semester = '2026-FALL';
  drop_enrollment(v_id, v_rows);
  DBMS_OUTPUT.PUT_LINE('Rows deleted = ' || v_rows);
END;
/

PROMPT ===== TEST 4 (test_course_roster): print_course_roster =====
-- Concepts: explicit cursor OPEN/FETCH/CLOSE, cursor-based record
-- EXPECTED: CS305 roster with 2 students (Mukamana, Uwase) and "Total enrolled: 2"
BEGIN
  print_course_roster(105, '2026-FALL');
END;
/

PROMPT ===== TEST 5 (test_grade_distribution): grade_distribution =====
-- Concepts: associative array + VARRAY + cursor FOR loop
-- EXPECTED: CS101 2025-FALL -> A:1 (33.3%), C:1, F:1, "Graded students: 3"
BEGIN
  grade_distribution(101, '2025-FALL');
END;
/

PROMPT ===== TEST 6 (test_bulk_import_success): bulk_import_grades =====
-- Concepts: BULK COLLECT ... LIMIT, FORALL SAVE EXCEPTIONS, SQL%BULK_ROWCOUNT
-- Batch size 3 forces 3 batches (3+3+1) so the batching logic is exercised.
-- EXPECTED: read=7, updated=5, failed=2
--           IMPORT_ERROR_LOG: one ORA-02290 (score 150) + one -20013 (no enrollment)
DECLARE
  v_read PLS_INTEGER;  v_upd PLS_INTEGER;  v_fail PLS_INTEGER;
BEGIN
  bulk_import_grades('2026-FALL', 3, v_read, v_upd, v_fail);
  DBMS_OUTPUT.PUT_LINE('OUT params -> read=' || v_read || ' updated=' || v_upd || ' failed=' || v_fail);
END;
/
SELECT staging_id, error_code, error_message FROM import_error_log ORDER BY log_id;
SELECT e.student_id, e.course_id, e.grade_score, e.letter_grade
  FROM enrollments e WHERE e.semester = '2026-FALL' ORDER BY e.student_id, e.course_id;

PROMPT ===== TEST 7 (test_recalculate_gpa): recalculate_gpa_bulk =====
-- Concepts: BULK COLLECT into 2 collections + FORALL UPDATE
-- EXPECTED: GPA recalculated for 8 students (all with graded work); 1008 and 1010 untouched (NULL)
DECLARE
  v_n PLS_INTEGER;
BEGIN
  recalculate_gpa_bulk(NULL, v_n);
  DBMS_OUTPUT.PUT_LINE('Students updated = ' || v_n);
END;
/
SELECT student_id, first_name, last_name, gpa FROM students ORDER BY student_id;

PROMPT ===== TEST 8 (test_functions): all functions, from SQL and PL/SQL =====
-- fn_letter_grade / fn_grade_points called from a SQL statement
SELECT 95 AS score, fn_letter_grade(95) AS letter, fn_grade_points(fn_letter_grade(95)) AS points FROM dual
UNION ALL SELECT 72.5, fn_letter_grade(72.5), fn_grade_points(fn_letter_grade(72.5)) FROM dual
UNION ALL SELECT 59.9, fn_letter_grade(59.9), fn_grade_points(fn_letter_grade(59.9)) FROM dual;

-- fn_calculate_gpa inside a query (EXPECTED 1001 -> 3.64 after TEST 6; matches students.gpa)
SELECT student_id, last_name, fn_calculate_gpa(student_id) AS gpa_function, gpa AS gpa_stored
  FROM students ORDER BY student_id;

-- fn_get_transcript: nested table consumed with TABLE()
SELECT * FROM TABLE(fn_get_transcript(1001));

-- called from an anonymous block
-- EXPECTED: seats 105 = 0 | seats 101 = 40 | 'Uwase' -> 1001
DECLARE
BEGIN
  DBMS_OUTPUT.PUT_LINE('Seats free CS305 2026-FALL : ' || fn_seats_available(105, '2026-FALL'));
  DBMS_OUTPUT.PUT_LINE('Seats free CS101 2026-FALL : ' || fn_seats_available(101, '2026-FALL'));
  DBMS_OUTPUT.PUT_LINE('Student id for Uwase       : ' || fn_find_student_by_last_name('Uwase'));
  DBMS_OUTPUT.PUT_LINE('GPA of student 1010 (none graded) : ' || NVL(TO_CHAR(fn_calculate_gpa(1010)), 'NULL (no graded courses)'));
END;
/

PROMPT ===== TEST 9 (test_benchmark): benchmark_bulk_vs_loop =====
-- Concepts: bulk vs row-by-row. EXPECTED: FORALL clearly faster; table left empty.
DECLARE
  v_loop NUMBER;  v_bulk NUMBER;
BEGIN
  benchmark_bulk_vs_loop(50000, v_loop, v_bulk);
END;
/
SELECT COUNT(*) AS perf_test_rows_left FROM perf_test;   -- EXPECTED 0

ROLLBACK;   -- leave the database as we found it (or COMMIT if you want to keep the results)
