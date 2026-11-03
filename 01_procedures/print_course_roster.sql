-- =====================================================================
-- print_course_roster : prints the class list of a course for a semester.
-- Concepts: EXPLICIT parameterised cursor with OPEN / FETCH / CLOSE,
--           cursor-based record (c_roster%ROWTYPE), %ROWCOUNT, %NOTFOUND,
--           %ISOPEN, user-defined exception.
-- Errors:  -20002 course not found       -20008 nobody enrolled
-- =====================================================================
CREATE OR REPLACE PROCEDURE print_course_roster (
  p_course_id IN courses.course_id%TYPE,
  p_semester  IN enrollments.semester%TYPE
) AS
  CURSOR c_roster (cp_course_id NUMBER, cp_semester VARCHAR2) IS
    SELECT s.student_id,
           s.first_name || ' ' || s.last_name AS full_name,
           e.grade_score,
           e.letter_grade
      FROM enrollments e
      JOIN students s ON s.student_id = e.student_id
     WHERE e.course_id = cp_course_id
       AND e.semester  = cp_semester
     ORDER BY s.last_name, s.first_name;

  v_row    c_roster%ROWTYPE;          -- cursor-based record
  v_course courses%ROWTYPE;           -- table-based record
  e_no_enrollments EXCEPTION;
BEGIN
  BEGIN
    SELECT * INTO v_course FROM courses WHERE course_id = p_course_id;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20002, 'Course ' || p_course_id || ' does not exist.');
  END;

  DBMS_OUTPUT.PUT_LINE('ROSTER: ' || v_course.course_code || ' - ' || v_course.title ||
                       ' | ' || p_semester || ' | capacity ' || v_course.capacity);
  DBMS_OUTPUT.PUT_LINE(RPAD('#', 4) || RPAD('ID', 7) || RPAD('Name', 24) || RPAD('Score', 8) || 'Grade');

  OPEN c_roster(p_course_id, p_semester);
  LOOP
    FETCH c_roster INTO v_row;
    EXIT WHEN c_roster%NOTFOUND;
    DBMS_OUTPUT.PUT_LINE(RPAD(c_roster%ROWCOUNT, 4) || RPAD(v_row.student_id, 7) ||
                         RPAD(v_row.full_name, 24) ||
                         RPAD(NVL(TO_CHAR(v_row.grade_score), '-'), 8) ||
                         NVL(v_row.letter_grade, '-'));
  END LOOP;

  IF c_roster%ROWCOUNT = 0 THEN
    CLOSE c_roster;
    RAISE e_no_enrollments;
  END IF;

  DBMS_OUTPUT.PUT_LINE('Total enrolled: ' || c_roster%ROWCOUNT);
  CLOSE c_roster;

EXCEPTION
  WHEN e_no_enrollments THEN
    RAISE_APPLICATION_ERROR(-20008,
      'No students enrolled in course ' || p_course_id || ' for ' || p_semester || '.');
  WHEN OTHERS THEN
    IF c_roster%ISOPEN THEN CLOSE c_roster; END IF;     -- never leak a cursor
    IF SQLCODE BETWEEN -20999 AND -20000 THEN
      RAISE;
    ELSE
      RAISE_APPLICATION_ERROR(-20099, 'print_course_roster failed: ' || SQLERRM, TRUE);
    END IF;
END print_course_roster;
/
SHOW ERRORS
