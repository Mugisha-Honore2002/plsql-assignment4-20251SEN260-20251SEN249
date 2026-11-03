-- =====================================================================
-- drop_enrollment : removes an UNGRADED enrollment.
-- Concepts: implicit DELETE cursor (SQL%NOTFOUND / SQL%ROWCOUNT),
--           user-defined exceptions, OUT parameter.
-- Errors:  -20006 enrollment already graded (cannot be dropped)
--          -20007 enrollment not found
-- =====================================================================
CREATE OR REPLACE PROCEDURE drop_enrollment (
  p_enrollment_id IN  enrollments.enrollment_id%TYPE,
  o_rows_deleted  OUT PLS_INTEGER
) AS
  e_already_graded EXCEPTION;
  e_not_found      EXCEPTION;
  v_exists         PLS_INTEGER;
BEGIN
  DELETE FROM enrollments
   WHERE enrollment_id = p_enrollment_id
     AND grade_score IS NULL;

  IF SQL%NOTFOUND THEN
    -- nothing deleted: either it does not exist, or it is already graded
    SELECT COUNT(*) INTO v_exists FROM enrollments WHERE enrollment_id = p_enrollment_id;
    IF v_exists = 0 THEN
      RAISE e_not_found;
    ELSE
      RAISE e_already_graded;
    END IF;
  END IF;

  o_rows_deleted := SQL%ROWCOUNT;
  DBMS_OUTPUT.PUT_LINE('Enrollment ' || p_enrollment_id || ' dropped (' || o_rows_deleted || ' row).');

EXCEPTION
  WHEN e_not_found THEN
    RAISE_APPLICATION_ERROR(-20007, 'Enrollment ' || p_enrollment_id || ' does not exist.');
  WHEN e_already_graded THEN
    RAISE_APPLICATION_ERROR(-20006,
      'Enrollment ' || p_enrollment_id || ' already has a grade and cannot be dropped.');
  WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20099, 'drop_enrollment failed: ' || SQLERRM, TRUE);
END drop_enrollment;
/
SHOW ERRORS
