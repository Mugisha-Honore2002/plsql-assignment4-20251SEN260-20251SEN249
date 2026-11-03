-- =====================================================================
-- fn_seats_available : free seats in a course for a semester.
-- Uses: %ROWTYPE record, SELECT INTO (NO_DATA_FOUND).
-- Errors:  -20002 course not found
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_seats_available (
  p_course_id IN courses.course_id%TYPE,
  p_semester  IN enrollments.semester%TYPE
) RETURN NUMBER
IS
  v_course courses%ROWTYPE;
  v_taken  NUMBER;
BEGIN
  SELECT * INTO v_course FROM courses WHERE course_id = p_course_id;

  SELECT COUNT(*) INTO v_taken
    FROM enrollments
   WHERE course_id = p_course_id
     AND semester  = p_semester;

  RETURN GREATEST(v_course.capacity - v_taken, 0);

EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20002, 'Course ' || p_course_id || ' does not exist.');
  WHEN OTHERS THEN
    IF SQLCODE BETWEEN -20999 AND -20000 THEN
      RAISE;
    ELSE
      RAISE_APPLICATION_ERROR(-20099, 'fn_seats_available failed: ' || SQLERRM, TRUE);
    END IF;
END fn_seats_available;
/
SHOW ERRORS
