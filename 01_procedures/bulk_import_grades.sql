-- =====================================================================
-- bulk_import_grades : loads staged grades into ENROLLMENTS in batches.
-- Concepts: explicit cursor + BULK COLLECT ... LIMIT into a nested table of
--           %ROWTYPE records, FORALL with SAVE EXCEPTIONS, SQL%BULK_ROWCOUNT,
--           SQL%BULK_EXCEPTIONS, PRAGMA EXCEPTION_INIT(-24381),
--           associative arrays, OUT parameters, implicit UPDATE (SQL%ROWCOUNT).
-- Outcome per staged row:
--     updated            -> counted in o_rows_updated
--     DB error (e.g. score 150 breaks CK_ENR_SCORE) -> logged in IMPORT_ERROR_LOG
--     no matching enrollment (0 rows updated)       -> logged with code -20013
-- Good rows are never blocked by bad rows.
-- Errors:  -20012 invalid batch size
-- Note: no COMMIT here - the caller owns the transaction.
-- =====================================================================
CREATE OR REPLACE PROCEDURE bulk_import_grades (
  p_semester     IN  enrollments.semester%TYPE,
  p_batch_size   IN  PLS_INTEGER DEFAULT 100,
  o_rows_read    OUT PLS_INTEGER,
  o_rows_updated OUT PLS_INTEGER,
  o_rows_failed  OUT PLS_INTEGER
) AS
  CURSOR c_stage IS
    SELECT *
      FROM grade_import_staging
     WHERE semester  = p_semester
       AND processed = 'N'
     ORDER BY staging_id;

  TYPE t_stage_tab IS TABLE OF grade_import_staging%ROWTYPE;    -- nested table of records
  v_stage t_stage_tab;

  TYPE t_int_tab  IS TABLE OF PLS_INTEGER INDEX BY PLS_INTEGER; -- associative arrays
  TYPE t_flag_tab IS TABLE OF BOOLEAN     INDEX BY PLS_INTEGER;
  v_rc       t_int_tab;     -- private copy of SQL%BULK_ROWCOUNT
  v_err_idx  t_int_tab;     -- private copy of SQL%BULK_EXCEPTIONS(j).ERROR_INDEX
  v_err_code t_int_tab;     -- private copy of SQL%BULK_EXCEPTIONS(j).ERROR_CODE
  v_failed   t_flag_tab;    -- which batch positions failed with a DB error
  v_err_cnt  PLS_INTEGER;

  e_bulk_errors EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_bulk_errors, -24381);

  PROCEDURE log_error (p_staging_id IN NUMBER, p_code IN NUMBER, p_msg IN VARCHAR2) IS
  BEGIN
    INSERT INTO import_error_log (staging_id, error_code, error_message)
    VALUES (p_staging_id, p_code, SUBSTR(p_msg, 1, 500));
  END log_error;
BEGIN
  IF p_batch_size IS NULL OR p_batch_size < 1 THEN
    RAISE_APPLICATION_ERROR(-20012, 'Batch size must be at least 1 (got ' || NVL(TO_CHAR(p_batch_size), 'NULL') || ').');
  END IF;

  o_rows_read := 0;  o_rows_updated := 0;  o_rows_failed := 0;

  OPEN c_stage;
  LOOP
    FETCH c_stage BULK COLLECT INTO v_stage LIMIT p_batch_size;
    EXIT WHEN v_stage.COUNT = 0;                 -- (not c_stage%NOTFOUND: would skip the last partial batch)
    o_rows_read := o_rows_read + v_stage.COUNT;

    v_rc.DELETE;  v_err_idx.DELETE;  v_err_code.DELETE;  v_failed.DELETE;
    v_err_cnt := 0;

    -- ONE call to the SQL engine for the whole batch
    BEGIN
      FORALL i IN 1 .. v_stage.COUNT SAVE EXCEPTIONS
        UPDATE enrollments
           SET grade_score = v_stage(i).score
         WHERE student_id = v_stage(i).student_id
           AND course_id  = v_stage(i).course_id
           AND semester   = v_stage(i).semester;
    EXCEPTION
      WHEN e_bulk_errors THEN
        v_err_cnt := SQL%BULK_EXCEPTIONS.COUNT;
        FOR j IN 1 .. v_err_cnt LOOP
          v_err_idx(j)  := SQL%BULK_EXCEPTIONS(j).ERROR_INDEX;
          v_err_code(j) := SQL%BULK_EXCEPTIONS(j).ERROR_CODE;
        END LOOP;
    END;

    -- copy per-row counts NOW, before any other DML resets the SQL% attributes
    FOR i IN 1 .. v_stage.COUNT LOOP
      v_rc(i) := SQL%BULK_ROWCOUNT(i);
    END LOOP;

    -- rows rejected by the database
    FOR j IN 1 .. v_err_cnt LOOP
      v_failed(v_err_idx(j)) := TRUE;
      log_error(v_stage(v_err_idx(j)).staging_id,
                -v_err_code(j),
                SQLERRM(-v_err_code(j)));
      o_rows_failed := o_rows_failed + 1;
    END LOOP;

    -- rows that ran fine: 1 = updated, 0 = no matching enrollment
    FOR i IN 1 .. v_stage.COUNT LOOP
      IF NOT v_failed.EXISTS(i) THEN
        IF v_rc(i) = 0 THEN
          log_error(v_stage(i).staging_id, -20013,
                    'No enrollment for student ' || v_stage(i).student_id ||
                    ' in course ' || v_stage(i).course_id || ' (' || v_stage(i).semester || ').');
          o_rows_failed := o_rows_failed + 1;
        ELSE
          o_rows_updated := o_rows_updated + v_rc(i);
        END IF;
      END IF;
    END LOOP;
  END LOOP;
  CLOSE c_stage;

  -- derive letter grades for every scored enrollment of the semester (set-based, one statement)
  UPDATE enrollments
     SET letter_grade = fn_letter_grade(grade_score)
   WHERE semester = p_semester
     AND grade_score IS NOT NULL;
  DBMS_OUTPUT.PUT_LINE('Letter grades derived for ' || SQL%ROWCOUNT || ' enrollments.');

  -- mark everything we looked at as processed (bad rows are in IMPORT_ERROR_LOG)
  UPDATE grade_import_staging
     SET processed = 'Y'
   WHERE semester = p_semester AND processed = 'N';

  DBMS_OUTPUT.PUT_LINE('Import finished: read=' || o_rows_read || ', updated=' || o_rows_updated ||
                       ', failed=' || o_rows_failed || ' (see IMPORT_ERROR_LOG).');

EXCEPTION
  WHEN OTHERS THEN
    IF c_stage%ISOPEN THEN CLOSE c_stage; END IF;
    IF SQLCODE BETWEEN -20999 AND -20000 THEN
      RAISE;
    ELSE
      RAISE_APPLICATION_ERROR(-20099, 'bulk_import_grades failed: ' || SQLERRM, TRUE);
    END IF;
END bulk_import_grades;
/
SHOW ERRORS
