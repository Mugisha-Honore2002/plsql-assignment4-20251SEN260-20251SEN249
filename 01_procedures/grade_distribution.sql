-- =====================================================================
-- grade_distribution : how many A/B/C/D/F in a course for a semester.
-- Concepts: ASSOCIATIVE ARRAY (key = letter grade, a key-value counter),
--           VARRAY (fixed, ordered list of the 5 letters for printing),
--           explicit cursor + cursor FOR loop.
-- Errors:  -20002 course not found   -20008 no graded enrollments
-- =====================================================================
CREATE OR REPLACE PROCEDURE grade_distribution (
  p_course_id IN courses.course_id%TYPE,
  p_semester  IN enrollments.semester%TYPE
) AS
  CURSOR c_grades IS
    SELECT letter_grade
      FROM enrollments
     WHERE course_id = p_course_id
       AND semester  = p_semester
       AND letter_grade IS NOT NULL;

  TYPE t_count_map IS TABLE OF PLS_INTEGER INDEX BY VARCHAR2(2);   -- associative array
  TYPE t_letters   IS VARRAY(5) OF VARCHAR2(2);                    -- VARRAY

  v_counts  t_count_map;
  v_letters t_letters := t_letters('A', 'B', 'C', 'D', 'F');
  v_total   PLS_INTEGER := 0;
  v_title   courses.title%TYPE;
BEGIN
  BEGIN
    SELECT title INTO v_title FROM courses WHERE course_id = p_course_id;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20002, 'Course ' || p_course_id || ' does not exist.');
  END;

  FOR i IN 1 .. v_letters.COUNT LOOP            -- start every bucket at 0
    v_counts(v_letters(i)) := 0;
  END LOOP;

  FOR r IN c_grades LOOP                        -- cursor FOR loop: auto OPEN/FETCH/CLOSE
    v_counts(r.letter_grade) := v_counts(r.letter_grade) + 1;
    v_total := v_total + 1;
  END LOOP;

  IF v_total = 0 THEN
    RAISE_APPLICATION_ERROR(-20008,
      'No graded enrollments for course ' || p_course_id || ' in ' || p_semester || '.');
  END IF;

  DBMS_OUTPUT.PUT_LINE('GRADE DISTRIBUTION: ' || v_title || ' | ' || p_semester);
  FOR i IN 1 .. v_letters.COUNT LOOP
    DBMS_OUTPUT.PUT_LINE(v_letters(i) || ': ' || RPAD(v_counts(v_letters(i)), 3) ||
                         ROUND(100 * v_counts(v_letters(i)) / v_total, 1) || '%  ' ||
                         RPAD('#', v_counts(v_letters(i)), '#'));
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('Graded students: ' || v_total);

EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE BETWEEN -20999 AND -20000 THEN
      RAISE;
    ELSE
      RAISE_APPLICATION_ERROR(-20099, 'grade_distribution failed: ' || SQLERRM, TRUE);
    END IF;
END grade_distribution;
/
SHOW ERRORS
