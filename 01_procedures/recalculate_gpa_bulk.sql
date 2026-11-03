-- =====================================================================
-- recalculate_gpa_bulk : recomputes STUDENTS.GPA for a department (or all).
-- Concepts: BULK COLLECT into two parallel nested tables, FORALL UPDATE with
--           SAVE EXCEPTIONS, SQL%BULK_EXCEPTIONS, SQL%ROWCOUNT, OUT parameter.
-- The GPA is computed set-based inside ONE query (no per-student function
-- call), then written back with ONE FORALL.
-- Students with no graded courses are left untouched (GPA stays as it was).
-- Errors:  -20014 department not found
--          -20015 some GPA updates failed (good ones are kept; caller decides)
-- =====================================================================
CREATE OR REPLACE PROCEDURE recalculate_gpa_bulk (
  p_dept_id          IN  departments.dept_id%TYPE DEFAULT NULL,
  o_students_updated OUT PLS_INTEGER
) AS
  TYPE t_id_tab  IS TABLE OF students.student_id%TYPE;
  TYPE t_gpa_tab IS TABLE OF students.gpa%TYPE;
  v_ids  t_id_tab;
  v_gpas t_gpa_tab;

  e_bulk_errors EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_bulk_errors, -24381);
  v_dummy departments.dept_id%TYPE;
BEGIN
  o_students_updated := 0;

  IF p_dept_id IS NOT NULL THEN
    BEGIN
      SELECT dept_id INTO v_dummy FROM departments WHERE dept_id = p_dept_id;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20014, 'Department ' || p_dept_id || ' does not exist.');
    END;
  END IF;

  SELECT s.student_id,
         ROUND(SUM(fn_grade_points(e.letter_grade) * c.credits) / SUM(c.credits), 2)
    BULK COLLECT INTO v_ids, v_gpas
    FROM students s
    JOIN enrollments e ON e.student_id = s.student_id
    JOIN courses     c ON c.course_id  = e.course_id
   WHERE e.letter_grade IS NOT NULL
     AND (p_dept_id IS NULL OR s.dept_id = p_dept_id)
   GROUP BY s.student_id;

  IF v_ids.COUNT = 0 THEN
    DBMS_OUTPUT.PUT_LINE('No graded students found - nothing to update.');
    RETURN;
  END IF;

  FORALL i IN 1 .. v_ids.COUNT SAVE EXCEPTIONS
    UPDATE students SET gpa = v_gpas(i) WHERE student_id = v_ids(i);

  o_students_updated := SQL%ROWCOUNT;
  DBMS_OUTPUT.PUT_LINE('GPA recalculated for ' || o_students_updated || ' students.');

EXCEPTION
  WHEN e_bulk_errors THEN
    DECLARE
      v_n PLS_INTEGER := SQL%BULK_EXCEPTIONS.COUNT;
    BEGIN
      FOR j IN 1 .. v_n LOOP
        DBMS_OUTPUT.PUT_LINE('GPA update failed for student ' ||
          v_ids(SQL%BULK_EXCEPTIONS(j).ERROR_INDEX) || ': ' ||
          SQLERRM(-SQL%BULK_EXCEPTIONS(j).ERROR_CODE));
      END LOOP;
      RAISE_APPLICATION_ERROR(-20015, v_n || ' GPA update(s) failed; see output for details.');
    END;
  WHEN OTHERS THEN
    IF SQLCODE BETWEEN -20999 AND -20000 THEN
      RAISE;
    ELSE
      RAISE_APPLICATION_ERROR(-20099, 'recalculate_gpa_bulk failed: ' || SQLERRM, TRUE);
    END IF;
END recalculate_gpa_bulk;
/
SHOW ERRORS
