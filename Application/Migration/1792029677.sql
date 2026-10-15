-- Restore referential integrity without changing any existing records.
-- IHP 1.6 wraps this migration and its revision entry in one transaction.
-- Existing orphan references or duplicate student/course pairs must be
-- resolved explicitly before this migration can succeed.
-- Do not use NOT VALID: every constraint must validate existing records.

SET LOCAL lock_timeout = '5s';

ALTER TABLE enrollments
    ADD CONSTRAINT enrollments_ref_student_id
        FOREIGN KEY (student_id) REFERENCES students (id)
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    ADD CONSTRAINT enrollments_ref_course_id
        FOREIGN KEY (course_id) REFERENCES courses (id)
        ON UPDATE NO ACTION ON DELETE NO ACTION,
    ADD CONSTRAINT enrollments_unique_student_course
        UNIQUE (student_id, course_id);

ALTER TABLE grades
    ADD CONSTRAINT grades_ref_enrollment_id
        FOREIGN KEY (enrollment_id) REFERENCES enrollments (id)
        ON UPDATE NO ACTION ON DELETE NO ACTION;
