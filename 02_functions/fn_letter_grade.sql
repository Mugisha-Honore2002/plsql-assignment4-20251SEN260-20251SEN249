-- =====================================================================
-- fn_letter_grade : converts a numeric score (0-100) to A/B/C/D/F.
-- Callable from SQL and PL/SQL.
-- Errors:  -20010 invalid or NULL score (never returns a misleading grade)
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_letter_grade (
  p_score IN NUMBER
) RETURN VARCHAR2
DETERMINISTIC
IS
  v_letter VARCHAR2(1);
BEGIN
  IF p_score IS NULL OR p_score < 0 OR p_score > 100 THEN
    RAISE_APPLICATION_ERROR(-20010,
      'Invalid score ' || NVL(TO_CHAR(p_score), 'NULL') || ': must be between 0 and 100.');
  END IF;

  v_letter := CASE
                WHEN p_score >= 90 THEN 'A'
                WHEN p_score >= 80 THEN 'B'
                WHEN p_score >= 70 THEN 'C'
                WHEN p_score >= 60 THEN 'D'
                ELSE 'F'
              END;
  RETURN v_letter;
END fn_letter_grade;
/
SHOW ERRORS
