-- =====================================================================
-- 02_insert_sample_data.sql  | Re-runnable: clears data, then reloads it.
-- =====================================================================
DELETE FROM import_error_log;
DELETE FROM grade_import_staging;
DELETE FROM grade_audit;
DELETE FROM enrollments;
DELETE FROM courses;
DELETE FROM students;
DELETE FROM departments;

-- Departments
INSERT INTO departments VALUES (10, 'Computer Science');
INSERT INTO departments VALUES (20, 'Information Systems');
INSERT INTO departments VALUES (30, 'Business Administration');

-- Students (note: 1002 and 1003 share a last name; 1008 is SUSPENDED)
INSERT INTO students (student_id, first_name, last_name, email, dept_id, status) VALUES (1001, 'Alice',    'Uwase',       'alice.uwase@auca.ac.rw',       10, 'ACTIVE');
INSERT INTO students (student_id, first_name, last_name, email, dept_id, status) VALUES (1002, 'Chantal',  'Mukamana',    'chantal.mukamana@auca.ac.rw',  10, 'ACTIVE');
INSERT INTO students (student_id, first_name, last_name, email, dept_id, status) VALUES (1003, 'Jean',     'Mukamana',    'jean.mukamana@auca.ac.rw',     20, 'ACTIVE');
INSERT INTO students (student_id, first_name, last_name, email, dept_id, status) VALUES (1004, 'David',    'Habimana',    'david.habimana@auca.ac.rw',    10, 'ACTIVE');
INSERT INTO students (student_id, first_name, last_name, email, dept_id, status) VALUES (1005, 'Grace',    'Ingabire',    'grace.ingabire@auca.ac.rw',    20, 'ACTIVE');
INSERT INTO students (student_id, first_name, last_name, email, dept_id, status) VALUES (1006, 'Eric',     'Niyonzima',   'eric.niyonzima@auca.ac.rw',    30, 'ACTIVE');
INSERT INTO students (student_id, first_name, last_name, email, dept_id, status) VALUES (1007, 'Sandra',   'Uwimana',     'sandra.uwimana@auca.ac.rw',    30, 'ACTIVE');
INSERT INTO students (student_id, first_name, last_name, email, dept_id, status) VALUES (1008, 'Patrick',  'Nkurunziza',  'patrick.nkurunziza@auca.ac.rw',10, 'SUSPENDED');
INSERT INTO students (student_id, first_name, last_name, email, dept_id, status) VALUES (1009, 'Diane',    'Mutesi',      'diane.mutesi@auca.ac.rw',      20, 'ACTIVE');
INSERT INTO students (student_id, first_name, last_name, email, dept_id, status) VALUES (1010, 'Kevin',    'Mugisha',     'kevin.mugisha@auca.ac.rw',     10, 'ACTIVE');

-- Courses (course 105 has capacity 2 so we can test "course full")
INSERT INTO courses VALUES (101, 'CS101', 'Introduction to Programming', 3, 10, 40);
INSERT INTO courses VALUES (102, 'CS201', 'Database Systems',            4, 10, 30);
INSERT INTO courses VALUES (103, 'IS210', 'Systems Analysis',            3, 20, 30);
INSERT INTO courses VALUES (104, 'BA110', 'Principles of Management',    3, 30, 30);
INSERT INTO courses VALUES (105, 'CS305', 'PL/SQL Development',          4, 10,  2);

-- Past semester: graded enrollments
INSERT INTO enrollments (student_id, course_id, semester, grade_score, letter_grade) VALUES (1001, 101, '2025-FALL', 92.5, 'A');
INSERT INTO enrollments (student_id, course_id, semester, grade_score, letter_grade) VALUES (1001, 102, '2025-FALL', 85,   'B');
INSERT INTO enrollments (student_id, course_id, semester, grade_score, letter_grade) VALUES (1002, 101, '2025-FALL', 78,   'C');
INSERT INTO enrollments (student_id, course_id, semester, grade_score, letter_grade) VALUES (1002, 102, '2025-FALL', 88,   'B');
INSERT INTO enrollments (student_id, course_id, semester, grade_score, letter_grade) VALUES (1003, 103, '2025-FALL', 95,   'A');
INSERT INTO enrollments (student_id, course_id, semester, grade_score, letter_grade) VALUES (1004, 101, '2025-FALL', 55,   'F');
INSERT INTO enrollments (student_id, course_id, semester, grade_score, letter_grade) VALUES (1004, 102, '2025-FALL', 67,   'D');
INSERT INTO enrollments (student_id, course_id, semester, grade_score, letter_grade) VALUES (1005, 103, '2025-FALL', 74,   'C');
INSERT INTO enrollments (student_id, course_id, semester, grade_score, letter_grade) VALUES (1006, 104, '2025-FALL', 81,   'B');
INSERT INTO enrollments (student_id, course_id, semester, grade_score, letter_grade) VALUES (1007, 104, '2025-FALL', 91,   'A');
INSERT INTO enrollments (student_id, course_id, semester, grade_score, letter_grade) VALUES (1009, 103, '2025-FALL', 69,   'D');

-- Current semester: not yet graded (course 105 is now full: 2/2)
INSERT INTO enrollments (student_id, course_id, semester) VALUES (1001, 105, '2026-FALL');
INSERT INTO enrollments (student_id, course_id, semester) VALUES (1002, 105, '2026-FALL');
INSERT INTO enrollments (student_id, course_id, semester) VALUES (1004, 102, '2026-FALL');
INSERT INTO enrollments (student_id, course_id, semester) VALUES (1003, 103, '2026-FALL');
INSERT INTO enrollments (student_id, course_id, semester) VALUES (1005, 103, '2026-FALL');
INSERT INTO enrollments (student_id, course_id, semester) VALUES (1006, 104, '2026-FALL');
INSERT INTO enrollments (student_id, course_id, semester) VALUES (1007, 104, '2026-FALL');

-- Staging grades for the bulk import (7 rows):
--   5 good rows | 1 invalid score (150 -> check constraint) | 1 with no matching enrollment
INSERT INTO grade_import_staging (student_id, course_id, semester, score) VALUES (1004, 102, '2026-FALL',  71.5);
INSERT INTO grade_import_staging (student_id, course_id, semester, score) VALUES (1003, 103, '2026-FALL',  88);
INSERT INTO grade_import_staging (student_id, course_id, semester, score) VALUES (1005, 103, '2026-FALL', 150);   -- INVALID
INSERT INTO grade_import_staging (student_id, course_id, semester, score) VALUES (1006, 104, '2026-FALL',  79);
INSERT INTO grade_import_staging (student_id, course_id, semester, score) VALUES (1007, 104, '2026-FALL',  93);
INSERT INTO grade_import_staging (student_id, course_id, semester, score) VALUES (1009, 104, '2026-FALL',  66);   -- NO ENROLLMENT
INSERT INTO grade_import_staging (student_id, course_id, semester, score) VALUES (1001, 105, '2026-FALL',  90);

COMMIT;
PROMPT Sample data loaded.
