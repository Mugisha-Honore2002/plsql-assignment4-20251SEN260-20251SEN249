-- =====================================================================
-- register_student_course : enrols a student in a course for a semester.
-- Concepts: user-defined record + %ROWTYPE records, implicit INSERT cursor
--           (SQL%ROWCOUNT), IN/OUT parameters, predefined exceptions
--           (NO_DATA_FOUND, DUP_VAL_ON_INDEX), user-defined exceptions,
--           RAISE_APPLICATION_ERROR.
-- Errors:  -20001 student not found      -20002 course not found
--          -20003 student not ACTIVE     -20004 course is full
--          -20005 already enrolled       -20009 unexpected insert row count
-- Note: no COMMIT here - the caller owns the transaction.
-- =====================================================================
CREATE OR REPLACE PROCEDURE register_student_course (
  p_student_id    IN  students.student_id%TYPE,
  p_course_id     IN  courses.course_id%TYPE,
  p_semester      IN  enrollments.semester%TYPE,
  o_enrollment_id OUT enrollments.enrollment_id%TYPE,
  o_message       OUT VARCHAR2
) AS
  -- user-defined record: the facts needed for the capacity check
  TYPE t_reg_check IS RECORD (
    student_name VARCHAR2(101),
    course_code  courses.course_code%TYPE,
    seats_taken  NUMBER,
    capacity     courses.capacity%TYPE
  );
  v_chk     t_reg_check;
  v_student students%ROWTYPE;   -- table-based record
  v_course  courses%ROWTYPE;    -- table-based record

  e_student_inactive EXCEPTION;
  e_course_full      EXCEPTION;
BEGIN
  -- 1. load student (predefined exception NO_DATA_FOUND -> meaningful message)
  BEGIN
    SELECT * INTO v_student FROM students WHERE student_id = p_student_id;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20001, 'Student ' || p_student_id || ' does not exist.');
  END;

  -- 2. load course
  BEGIN
    SELECT * INTO v_course FROM courses WHERE course_id = p_course_id;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20002, 'Course ' || p_course_id || ' does not exist.');
  END;

  -- 3. business rules
  IF v_student.status <> 'ACTIVE' THEN
    RAISE e_student_inactive;
  END IF;

  SELECT COUNT(*) INTO v_chk.seats_taken
    FROM enrollments
   WHERE course_id = p_course_id AND semester = p_semester;

  v_chk.student_name := v_student.first_name || ' ' || v_student.last_name;
  v_chk.course_code  := v_course.course_code;
  v_chk.capacity     := v_course.capacity;

  IF v_chk.seats_taken >= v_chk.capacity THEN
    RAISE e_course_full;
  END IF;

  -- 4. implicit cursor: INSERT ... RETURNING
  INSERT INTO enrollments (student_id, course_id, semester)
  VALUES (p_student_id, p_course_id, p_semester)
  RETURNING enrollment_id INTO o_enrollment_id;

  IF SQL%ROWCOUNT <> 1 THEN
    RAISE_APPLICATION_ERROR(-20009, 'Unexpected row count ' || SQL%ROWCOUNT || ' on enrollment insert.');
  END IF;

  o_message := v_chk.student_name || ' enrolled in ' || v_chk.course_code ||
               ' for ' || p_semester || ' (seat ' || (v_chk.seats_taken + 1) ||
               ' of ' || v_chk.capacity || ').';

EXCEPTION
  WHEN e_student_inactive THEN
    RAISE_APPLICATION_ERROR(-20003,
      'Student ' || p_student_id || ' has status ' || v_student.status || ' and cannot register.');
  WHEN e_course_full THEN
    RAISE_APPLICATION_ERROR(-20004,
      'Course ' || v_chk.course_code || ' is full (' || v_chk.seats_taken || '/' || v_chk.capacity ||
      ') for ' || p_semester || '.');
  WHEN DUP_VAL_ON_INDEX THEN
    RAISE_APPLICATION_ERROR(-20005,
      'Student ' || p_student_id || ' is already enrolled in course ' || p_course_id ||
      ' for ' || p_semester || '.');
  WHEN OTHERS THEN
    IF SQLCODE BETWEEN -20999 AND -20000 THEN
      RAISE;   -- business error already raised above: pass it on untouched
    ELSE
      RAISE_APPLICATION_ERROR(-20099, 'register_student_course failed: ' || SQLERRM, TRUE);
    END IF;
END register_student_course;
/
SHOW ERRORS
