-- =====================================================================
-- fn_get_transcript : returns a student's transcript as a NESTED TABLE of
-- objects, filled with a single BULK COLLECT. Usable in SQL via TABLE():
--     SELECT * FROM TABLE(fn_get_transcript(1001));
-- Requires types t_transcript_obj / t_transcript_tab (01_create_tables.sql).
-- An empty collection is returned when the student exists but has no
-- enrollments (this is the truthful answer, not an error).
-- Errors:  -20001 student not found
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_get_transcript (
  p_student_id IN students.student_id%TYPE
) RETURN t_transcript_tab
IS
  v_transcript t_transcript_tab;
  v_id         students.student_id%TYPE;
BEGIN
  BEGIN
    SELECT student_id INTO v_id FROM students WHERE student_id = p_student_id;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20001, 'Student ' || p_student_id || ' does not exist.');
  END;

  SELECT t_transcript_obj(c.course_code, c.title, c.credits,
                          e.semester, e.grade_score, e.letter_grade)
    BULK COLLECT INTO v_transcript
    FROM enrollments e
    JOIN courses c ON c.course_id = e.course_id
   WHERE e.student_id = p_student_id
   ORDER BY e.semester, c.course_code;

  RETURN v_transcript;

EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE BETWEEN -20999 AND -20000 THEN
      RAISE;
    ELSE
      RAISE_APPLICATION_ERROR(-20099, 'fn_get_transcript failed: ' || SQLERRM, TRUE);
    END IF;
END fn_get_transcript;
/
SHOW ERRORS
