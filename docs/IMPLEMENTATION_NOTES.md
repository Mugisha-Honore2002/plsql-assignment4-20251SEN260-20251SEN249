# Implementation & Performance Notes

## 1. Design overview
The application is organised as **stored procedures** (do work, change data) and **stored functions** (compute and return values, usable from SQL).

| Layer | Objects |
|-------|---------|
| Data-changing procedures | `register_student_course`, `update_grade`, `drop_enrollment`, `bulk_import_grades`, `recalculate_gpa_bulk` |
| Reporting procedures | `print_course_roster`, `grade_distribution` |
| Utility procedure | `benchmark_bulk_vs_loop` |
| Functions | `fn_letter_grade`, `fn_grade_points`, `fn_calculate_gpa`, `fn_seats_available`, `fn_find_student_by_last_name`, `fn_get_transcript` |

### Key design decisions
* **Caller owns the transaction.** Procedures do not `COMMIT`/`ROLLBACK`; a business error therefore never half-commits work, and tests can roll back. (`benchmark_bulk_vs_loop` only rolls back to its own `SAVEPOINT`.)
* **Errors are raised, not printed and ignored.** Every business failure uses `RAISE_APPLICATION_ERROR` with a code in -20001…-20099 and a message naming the offending value. Each unit ends with a `WHEN OTHERS` handler that **re-raises** our own codes untouched and wraps anything unexpected as `-20099` with `SQLERRM` (third argument `TRUE` keeps the original error in the stack). Nothing is silently swallowed.
* **Functions never return misleading values.** `fn_letter_grade` raises on NULL/out-of-range scores instead of returning `'F'`; `fn_calculate_gpa` returns `NULL` (not 0) when no grades exist; `fn_get_transcript` returns an empty collection only when the student exists but has no courses.
* **Validation lives in two places on purpose:** `CHECK` constraints protect the data no matter who writes to it; PL/SQL checks give friendly messages before the database error would occur.

## 2. How the required concepts are used
* **Records:** `%ROWTYPE` (table-based and cursor-based) for whole rows; user-defined `RECORD` types where only some fields are needed (`t_reg_check`, `t_totals`).
* **Collections:** associative arrays for key-value counting (`grade_distribution`) and for flags/copies of bulk attributes (`bulk_import_grades`); a nested table of records for batches (`t_stage_tab`); a `VARRAY(5)` for the fixed, ordered list of letter grades; a SQL-level nested table of objects (`t_transcript_tab`) so a function can be queried with `TABLE()`.
* **Implicit cursors:** `INSERT … RETURNING` + `SQL%ROWCOUNT`; `UPDATE` + `SQL%NOTFOUND` + `SQL%ROWCOUNT`; `DELETE` + `SQL%NOTFOUND`/`SQL%ROWCOUNT`. Values of `SQL%` attributes are copied into variables *before* the next DML statement, because every new statement overwrites them.
* **Explicit cursors:** parameterised cursor with `OPEN/FETCH/CLOSE` and `%NOTFOUND/%ROWCOUNT/%ISOPEN` (`print_course_roster`); cursor `FOR` loops (`grade_distribution`, `fn_calculate_gpa`); an explicit cursor feeding `BULK COLLECT … LIMIT` (`bulk_import_grades`). Cursors are closed in the exception handler if still open.
* **Exceptions:** predefined (`NO_DATA_FOUND`, `TOO_MANY_ROWS`, `DUP_VAL_ON_INDEX`), user-defined (`e_course_full`, `e_student_inactive`, `e_no_enrollments`, `e_already_graded`, `e_not_found`), `PRAGMA EXCEPTION_INIT(…, -24381)` for bulk errors, and `RAISE_APPLICATION_ERROR` throughout.

## 3. Bulk processing and performance

### Why row-by-row is slow
PL/SQL and SQL are two separate engines. Every SQL statement executed inside a PL/SQL loop forces a **context switch** from the PL/SQL engine to the SQL engine and back. For 50,000 inserts that is 50,000 round trips inside the server, each with its own parse/bind/execute overhead.

### What bulk processing changes
* `BULK COLLECT` moves *all* (or a `LIMIT`-sized batch of) result rows from SQL to PL/SQL in **one** switch instead of one per row.
* `FORALL` sends the *whole collection* of bind values to the SQL engine in **one** switch, which then runs the DML for each element. It is not a loop – it is a single bulk-bound statement.

### Where it is used in this project
| Procedure | Row-by-row alternative | Bulk approach used |
|-----------|-----------------------|--------------------|
| `bulk_import_grades` | one `UPDATE` per staged grade | `BULK COLLECT … LIMIT n` + one `FORALL UPDATE` per batch |
| `recalculate_gpa_bulk` | loop over students calling `fn_calculate_gpa` + 1 `UPDATE` each | one aggregate query with `BULK COLLECT`, one `FORALL UPDATE` |
| `fn_get_transcript` | cursor loop + `EXTEND` | single `BULK COLLECT` into a nested table |

### `LIMIT` and memory
Unbounded `BULK COLLECT` loads everything into PGA memory. `bulk_import_grades` fetches `p_batch_size` rows at a time (default 100) so memory stays flat however large the staging table is. The loop exits on `v_stage.COUNT = 0` (not `%NOTFOUND`), otherwise the last, partially-filled batch would be skipped.

### Bulk DML error handling
A plain `FORALL` stops at the first failing row. With `SAVE EXCEPTIONS` Oracle continues, then raises ORA-24381 at the end. We trap it with `PRAGMA EXCEPTION_INIT`, read `SQL%BULK_EXCEPTIONS(j).ERROR_INDEX/ERROR_CODE`, and write each failure to `IMPORT_ERROR_LOG`. A second class of "failure" – an `UPDATE` that matched **no** row – raises no error at all, so we detect it with `SQL%BULK_ROWCOUNT(i) = 0` and log it too. The row counts and error details are copied to local collections immediately, because the logging `INSERT`s would otherwise overwrite the `SQL%` attributes.

### Measuring it
Run `benchmark_bulk_vs_loop` (TEST 9). Fill in your own results here after running it:

| Rows | FOR loop (cs) | FORALL (cs) | Speed-up |
|------|--------------|-------------|----------|
| 10 | _?_ | _?_ | _?_ |
| 50| _?_ | _?_ | _?_ |
| 100 | _?_ | _?_ | _?_ |

Timings depend on hardware, indexes and redo settings; the *relationship* (bulk markedly faster, gap widening with volume) is what matters.

### When NOT to use bulk
When each row needs different logic, per-row error handling with different recovery, or the data set is tiny, a plain cursor loop is clearer and the saving is negligible. A single set-based SQL statement (one `UPDATE … WHERE`) beats both when the logic can be expressed in SQL – e.g. the final "derive letter grades" step in `bulk_import_grades` is one `UPDATE`.

## 4. Known limitations / possible extensions
* Transaction control (`COMMIT`) is left to the caller / application layer.
* Capacity checking is not concurrency-proof: two sessions could both see one free seat. A production system would lock the course row (`SELECT … FOR UPDATE`) before counting.
* `fn_find_student_by_last_name` is intentionally ambiguous for shared names, to demonstrate `TOO_MANY_ROWS`.
* Could be wrapped in a package (`registration_pkg`) and extended with REF CURSOR reports.
