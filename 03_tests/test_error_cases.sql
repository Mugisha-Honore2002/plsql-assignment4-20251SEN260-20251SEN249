-- =====================================================================
-- test_error_cases.sql
-- Every block is EXPECTED to fail; the handler prints what was caught.
-- Run AFTER test_success_cases.sql has been run once (needs the same data), or
-- after reloading 02_insert_sample_data.sql (E4 needs course 105 to be full).
-- =====================================================================
SET SERVEROUTPUT ON SIZE UNLIMITED;

PROMPT ===== E1 (test_err_student_not_found): student 9999 -> ORA-20001 =====
DECLARE v_id NUMBER; v_msg VARCHAR2(400);
BEGIN
  register_student_course(9999, 101, '2026-FALL', v_id, v_msg);
  DBMS_OUTPUT.PUT_LINE('!! TEST FAILED: no error raised');
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Caught as expected: ' || SQLERRM);
END;
/

PROMPT ===== E2 (test_err_course_not_found): course 999 -> ORA-20002 =====
DECLARE v_id NUMBER; v_msg VARCHAR2(400);
BEGIN
  register_student_course(1001, 999, '2026-FALL', v_id, v_msg);
  DBMS_OUTPUT.PUT_LINE('!! TEST FAILED: no error raised');
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Caught as expected: ' || SQLERRM);
END;
/

PROMPT ===== E3 (test_err_student_suspended): user-defined exception -> ORA-20003 =====
DECLARE v_id NUMBER; v_msg VARCHAR2(400);
BEGIN
  register_student_course(1008, 101, '2026-FALL', v_id, v_msg);
  DBMS_OUTPUT.PUT_LINE('!! TEST FAILED: no error raised');
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Caught as expected: ' || SQLERRM);
END;
/

PROMPT ===== E4 (test_err_course_full): CS305 is 2/2 -> ORA-20004 =====
DECLARE v_id NUMBER; v_msg VARCHAR2(400);
BEGIN
  register_student_course(1003, 105, '2026-FALL', v_id, v_msg);
  DBMS_OUTPUT.PUT_LINE('!! TEST FAILED: no error raised');
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Caught as expected: ' || SQLERRM);
END;
/

PROMPT ===== E5 (test_err_duplicate_enrollment): DUP_VAL_ON_INDEX -> ORA-20005 =====
DECLARE v_id NUMBER; v_msg VARCHAR2(400);
BEGIN
  register_student_course(1004, 102, '2026-FALL', v_id, v_msg);   -- already enrolled
  DBMS_OUTPUT.PUT_LINE('!! TEST FAILED: no error raised');
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Caught as expected: ' || SQLERRM);
END;
/

PROMPT ===== E6 (test_err_update_grade): bad enrollment id / bad score =====
DECLARE v_letter VARCHAR2(2);
BEGIN
  update_grade(0, 80, v_letter);                                    -- ORA-20007
  DBMS_OUTPUT.PUT_LINE('!! TEST FAILED: no error raised');
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Caught as expected: ' || SQLERRM);
END;
/
DECLARE v_letter VARCHAR2(2); v_id NUMBER;
BEGIN
  SELECT MIN(enrollment_id) INTO v_id FROM enrollments;
  update_grade(v_id, 120, v_letter);                                -- ORA-20010
  DBMS_OUTPUT.PUT_LINE('!! TEST FAILED: no error raised');
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Caught as expected: ' || SQLERRM);
END;
/

PROMPT ===== E7 (test_err_drop_enrollment): graded -> ORA-20006 ; missing -> ORA-20007 =====
DECLARE v_id NUMBER; v_rows PLS_INTEGER;
BEGIN
  SELECT MIN(enrollment_id) INTO v_id FROM enrollments WHERE grade_score IS NOT NULL;
  drop_enrollment(v_id, v_rows);
  DBMS_OUTPUT.PUT_LINE('!! TEST FAILED: no error raised');
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Caught as expected: ' || SQLERRM);
END;
/
DECLARE v_rows PLS_INTEGER;
BEGIN
  drop_enrollment(-1, v_rows);
  DBMS_OUTPUT.PUT_LINE('!! TEST FAILED: no error raised');
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Caught as expected: ' || SQLERRM);
END;
/

PROMPT ===== E8 (test_err_empty_roster): user-defined exception e_no_enrollments -> ORA-20008 =====
BEGIN
  print_course_roster(104, '2030-SPRING');
  DBMS_OUTPUT.PUT_LINE('!! TEST FAILED: no error raised');
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Caught as expected: ' || SQLERRM);
END;
/

PROMPT ===== E9 (test_err_predefined_exceptions): NO_DATA_FOUND and TOO_MANY_ROWS =====
BEGIN
  DBMS_OUTPUT.PUT_LINE(fn_find_student_by_last_name('Nobody'));     -- NO_DATA_FOUND  -> ORA-20030
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Caught as expected: ' || SQLERRM);
END;
/
BEGIN
  DBMS_OUTPUT.PUT_LINE(fn_find_student_by_last_name('Mukamana'));   -- TOO_MANY_ROWS  -> ORA-20031
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Caught as expected: ' || SQLERRM);
END;
/

PROMPT ===== E10 (test_err_function_validation): invalid inputs to functions =====
BEGIN
  DBMS_OUTPUT.PUT_LINE(fn_letter_grade(101));                       -- ORA-20010
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Caught as expected: ' || SQLERRM);
END;
/
BEGIN
  DBMS_OUTPUT.PUT_LINE(fn_letter_grade(NULL));                      -- ORA-20010
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Caught as expected: ' || SQLERRM);
END;
/
BEGIN
  DBMS_OUTPUT.PUT_LINE(fn_grade_points('Z'));                       -- ORA-20011
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Caught as expected: ' || SQLERRM);
END;
/
BEGIN
  DBMS_OUTPUT.PUT_LINE(fn_calculate_gpa(9999));                     -- ORA-20001
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Caught as expected: ' || SQLERRM);
END;
/
BEGIN
  DBMS_OUTPUT.PUT_LINE(fn_seats_available(999, '2026-FALL'));       -- ORA-20002
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Caught as expected: ' || SQLERRM);
END;
/
DECLARE v_t t_transcript_tab;
BEGIN
  v_t := fn_get_transcript(9999);                                   -- ORA-20001
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Caught as expected: ' || SQLERRM);
END;
/

PROMPT ===== E11 (test_err_bulk_parameters): bad batch size / dept / row count =====
DECLARE a PLS_INTEGER; b PLS_INTEGER; c PLS_INTEGER;
BEGIN
  bulk_import_grades('2026-FALL', 0, a, b, c);                      -- ORA-20012
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Caught as expected: ' || SQLERRM);
END;
/
DECLARE n PLS_INTEGER;
BEGIN
  recalculate_gpa_bulk(999, n);                                     -- ORA-20014
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Caught as expected: ' || SQLERRM);
END;
/
DECLARE l NUMBER; b NUMBER;
BEGIN
  benchmark_bulk_vs_loop(0, l, b);                                  -- ORA-20016
EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Caught as expected: ' || SQLERRM);
END;
/

PROMPT ===== E12 (test_err_bulk_dml_errors): FORALL SAVE EXCEPTIONS keeps going =====
-- Stage 3 new rows (1 good, 1 bad score, 1 missing enrollment) and import with batch size 2.
-- EXPECTED: no exception escapes; read=3 updated=1 failed=2, and 2 NEW rows in IMPORT_ERROR_LOG.
DECLARE a PLS_INTEGER; b PLS_INTEGER; c PLS_INTEGER;
BEGIN
  INSERT INTO grade_import_staging (student_id, course_id, semester, score) VALUES (1004, 102, '2026-FALL',  72);
  INSERT INTO grade_import_staging (student_id, course_id, semester, score) VALUES (1005, 103, '2026-FALL', 150);
  INSERT INTO grade_import_staging (student_id, course_id, semester, score) VALUES (1009, 104, '2026-FALL',  66);
  bulk_import_grades('2026-FALL', 2, a, b, c);
  DBMS_OUTPUT.PUT_LINE('read=' || a || ' updated=' || b || ' failed=' || c);
END;
/
SELECT staging_id, error_code, error_message FROM import_error_log ORDER BY log_id;

PROMPT ===== E13 (test_err_constraint_violation): unexpected DB error is NOT hidden =====
BEGIN
  INSERT INTO enrollments (student_id, course_id, semester, grade_score)
  VALUES (1010, 101, '2026-FALL', 150);                             -- violates CK_ENR_SCORE
  DBMS_OUTPUT.PUT_LINE('!! TEST FAILED: no error raised');
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Caught as expected: ' || SQLERRM);
    ROLLBACK;
END;
/

ROLLBACK;
