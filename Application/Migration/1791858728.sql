ALTER TABLE courses ALTER COLUMN workload SET NOT NULL;
ALTER TABLE enrollments ALTER COLUMN status SET DEFAULT 'Active';
ALTER TABLE grades ALTER COLUMN score SET NOT NULL;
ALTER TABLE grades ALTER COLUMN weight SET NOT NULL;
ALTER TABLE students ALTER COLUMN enrollment_number SET NOT NULL;
ALTER TABLE enrollments DROP CONSTRAINT enrollments_unique_student_course;
ALTER TABLE enrollments DROP CONSTRAINT enrollments_ref_course_id;
ALTER TABLE enrollments DROP CONSTRAINT enrollments_ref_student_id;
