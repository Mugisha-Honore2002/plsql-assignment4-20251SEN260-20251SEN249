-- =====================================================================
-- fn_grade_points : maps a letter grade to 4.0-scale points.
-- Errors:  -20011 unknown letter grade
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_grade_points (
  p_letter IN VARCHAR2
) RETURN NUMBER
DETERMINISTIC
IS
BEGIN
  IF UPPER(p_letter) = 'A' THEN RETURN 4;
  ELSIF UPPER(p_letter) = 'B' THEN RETURN 3;
  ELSIF UPPER(p_letter) = 'C' THEN RETURN 2;
  ELSIF UPPER(p_letter) = 'D' THEN RETURN 1;
  ELSIF UPPER(p_letter) = 'F' THEN RETURN 0;
  ELSE
    RAISE_APPLICATION_ERROR(-20011,
      'Unknown letter grade ''' || NVL(p_letter, 'NULL') || ''' (expected A, B, C, D or F).');
  END IF;
END fn_grade_points;
/
SHOW ERRORS
