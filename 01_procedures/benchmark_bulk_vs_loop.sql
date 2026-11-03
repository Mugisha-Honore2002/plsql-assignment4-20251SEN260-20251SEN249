-- =====================================================================
-- benchmark_bulk_vs_loop : inserts N rows (a) row-by-row in a FOR loop and
-- (b) with one FORALL, and reports both timings in centiseconds.
-- Everything is rolled back to a SAVEPOINT, so PERF_TEST stays empty and the
-- caller's earlier uncommitted work is NOT undone.
-- Errors:  -20016 invalid row count (must be 1..1,000,000)
-- =====================================================================
CREATE OR REPLACE PROCEDURE benchmark_bulk_vs_loop (
  p_rows    IN  PLS_INTEGER DEFAULT 10000,
  o_loop_cs OUT NUMBER,
  o_bulk_cs OUT NUMBER
) AS
  TYPE t_id_tab  IS TABLE OF PLS_INTEGER INDEX BY PLS_INTEGER;
  TYPE t_txt_tab IS TABLE OF VARCHAR2(50) INDEX BY PLS_INTEGER;
  v_ids      t_id_tab;
  v_txt      t_txt_tab;
  v_start    NUMBER;
  v_sp_set   BOOLEAN := FALSE;
BEGIN
  IF p_rows IS NULL OR p_rows < 1 OR p_rows > 1000000 THEN
    RAISE_APPLICATION_ERROR(-20016, 'p_rows must be between 1 and 1,000,000.');
  END IF;

  SAVEPOINT before_benchmark;
  v_sp_set := TRUE;

  -- (a) row-by-row: one PL/SQL -> SQL context switch PER ROW
  v_start := DBMS_UTILITY.GET_TIME;
  FOR i IN 1 .. p_rows LOOP
    INSERT INTO perf_test (id, payload, created) VALUES (i, 'row ' || i, SYSDATE);
  END LOOP;
  o_loop_cs := DBMS_UTILITY.GET_TIME - v_start;
  ROLLBACK TO SAVEPOINT before_benchmark;

  -- (b) bulk: build the collections in memory, then ONE context switch
  FOR i IN 1 .. p_rows LOOP
    v_ids(i) := i;
    v_txt(i) := 'row ' || i;
  END LOOP;

  v_start := DBMS_UTILITY.GET_TIME;
  FORALL i IN 1 .. p_rows
    INSERT INTO perf_test (id, payload, created) VALUES (v_ids(i), v_txt(i), SYSDATE);
  o_bulk_cs := DBMS_UTILITY.GET_TIME - v_start;
  ROLLBACK TO SAVEPOINT before_benchmark;

  DBMS_OUTPUT.PUT_LINE('Rows inserted per method : ' || p_rows);
  DBMS_OUTPUT.PUT_LINE('FOR loop (row-by-row)    : ' || o_loop_cs || ' cs');
  DBMS_OUTPUT.PUT_LINE('FORALL   (bulk)          : ' || o_bulk_cs || ' cs');
  IF o_bulk_cs > 0 THEN
    DBMS_OUTPUT.PUT_LINE('Speed-up                 : ~' || ROUND(o_loop_cs / o_bulk_cs, 1) || 'x');
  ELSE
    DBMS_OUTPUT.PUT_LINE('Speed-up                 : bulk too fast to measure at this size - increase p_rows');
  END IF;

EXCEPTION
  WHEN OTHERS THEN
    IF v_sp_set THEN ROLLBACK TO SAVEPOINT before_benchmark; END IF;
    IF SQLCODE BETWEEN -20999 AND -20000 THEN
      RAISE;
    ELSE
      RAISE_APPLICATION_ERROR(-20099, 'benchmark_bulk_vs_loop failed: ' || SQLERRM, TRUE);
    END IF;
END benchmark_bulk_vs_loop;
/
SHOW ERRORS
