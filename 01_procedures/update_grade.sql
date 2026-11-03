-- =====================================================================
-- update_grade : sets the score for one enrollment, derives the letter
--                grade, and writes an audit row.
-- Concepts: %ROWTYPE record, implicit UPDATE cursor
--           (SQL%NOTFOUND, SQL%FOUND-style check, SQL%ROWCOUNT),
--           OUT parameter, function call (fn_letter_grade).
-- Errors:  -20007 enrollment not found   -20010 invalid score
-- =====================================================================
CREATE OR REPLACE PROCEDURE update_grade (
  p_enrollment_id IN  enrollments.enrollment_id%TYPE,
  p_new_score     IN  enrollments.grade_score%TYPE,
  o_letter_grade  OUT enrollments.letter_grade%TYPE
) AS
  v_old  enrollments%ROWTYPE;
  v_rows PLS_INTEGER;
BEGIN
  -- validates the range; raises -20010 for NULL / <0 / >100
  o_letter_grade := fn_letter_grade(p_new_score);

  -- read (and lock) the current row so the audit trail is accurate
  BEGIN
    SELECT * INTO v_old
      FROM enrollments
     WHERE enrollment_id = p_enrollment_id
       FOR UPDATE;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20007, 'Enrollment ' || p_enrollment_id || ' does not exist.');
  END;

  UPDATE enrollments
     SET grade_score  = p_new_score,
         letter_grade = o_letter_grade
   WHERE enrollment_id = p_enrollment_id;

  IF SQL%NOTFOUND THEN          -- defensive: row vanished between SELECT and UPDATE
    RAISE_APPLICATION_ERROR(-20007, 'Enrollment ' || p_enrollment_id || ' could not be updated.');
  END IF;
  v_rows := SQL%ROWCOUNT;       -- capture BEFORE the next DML overwrites SQL%

  INSERT INTO grade_audit (enrollment_id, old_score, new_score)
  VALUES (p_enrollment_id, v_old.grade_score, p_new_score);

  DBMS_OUTPUT.PUT_LINE('Enrollment ' || p_enrollment_id || ': ' ||
                       NVL(TO_CHAR(v_old.grade_score), 'none') || ' -> ' || p_new_score ||
                       ' (' || o_letter_grade || '), rows updated: ' || v_rows);
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE BETWEEN -20999 AND -20000 THEN
      RAISE;
    ELSE
      RAISE_APPLICATION_ERROR(-20099, 'update_grade failed: ' || SQLERRM, TRUE);
    END IF;
END update_grade;
/
SHOW ERRORS
