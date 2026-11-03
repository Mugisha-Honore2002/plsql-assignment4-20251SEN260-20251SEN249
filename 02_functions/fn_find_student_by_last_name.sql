-- =====================================================================
-- fn_find_student_by_last_name : returns the student_id for a last name.
-- Demonstrates PREDEFINED exceptions NO_DATA_FOUND and TOO_MANY_ROWS, each
-- translated to a meaningful application error (never silently swallowed).
-- Errors:  -20030 nobody has that last name
--          -20031 more than one student has that last name (ambiguous)
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_find_student_by_last_name (
  p_last_name IN students.last_name%TYPE
) RETURN students.student_id%TYPE
IS
  v_id students.student_id%TYPE;
BEGIN
  SELECT student_id
    INTO v_id
    FROM students
   WHERE UPPER(last_name) = UPPER(p_last_name);
  RETURN v_id;

EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20030, 'No student found with last name ''' || p_last_name || '''.');
  WHEN TOO_MANY_ROWS THEN
    RAISE_APPLICATION_ERROR(-20031,
      'Last name ''' || p_last_name || ''' is ambiguous: several students share it. Search by student_id instead.');
  WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20099, 'fn_find_student_by_last_name failed: ' || SQLERRM, TRUE);
END fn_find_student_by_last_name;
/
SHOW ERRORS
