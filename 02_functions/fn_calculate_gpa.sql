-- =====================================================================
-- fn_calculate_gpa : credit-weighted GPA (4.0 scale) for one student.
-- Uses: explicit parameterised cursor, cursor FOR loop, user-defined record.
-- Returns NULL (not 0) when the student has no graded courses yet, because
-- 0.00 would be a misleading result.
-- Errors:  -20001 student not found
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_calculate_gpa (
  p_student_id IN students.student_id%TYPE
) RETURN NUMBER
IS
  CURSOR c_grades (cp_student_id NUMBER) IS
    SELECT c.credits, e.letter_grade
      FROM enrollments e
      JOIN courses c ON c.course_id = e.course_id
     WHERE e.student_id   = cp_student_id
       AND e.letter_grade IS NOT NULL;

  -- user-defined record that accumulates the running totals
  TYPE t_totals IS RECORD (
    quality_points NUMBER := 0,
    credits        NUMBER := 0
  );
  v_tot t_totals;
  v_id  students.student_id%TYPE;
BEGIN
  BEGIN
    SELECT student_id INTO v_id FROM students WHERE student_id = p_student_id;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20001, 'Student ' || p_student_id || ' does not exist.');
  END;

  FOR r IN c_grades(p_student_id) LOOP
    v_tot.quality_points := v_tot.quality_points + fn_grade_points(r.letter_grade) * r.credits;
    v_tot.credits        := v_tot.credits + r.credits;
  END LOOP;

  IF v_tot.credits = 0 THEN
    RETURN NULL;   -- no graded work yet: GPA is undefined, not zero
  END IF;
  RETURN ROUND(v_tot.quality_points / v_tot.credits, 2);

EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE BETWEEN -20999 AND -20000 THEN
      RAISE;   -- our own business errors pass through unchanged
    ELSE
      RAISE_APPLICATION_ERROR(-20099, 'fn_calculate_gpa failed: ' || SQLERRM, TRUE);
    END IF;
END fn_calculate_gpa;
/
SHOW ERRORS
