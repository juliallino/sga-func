-- Enrollment is now a student/subject relationship.
-- Refuse to infer a subject for legacy records. Approved data cleanup must
-- be performed separately, with verified backup and exact UUID manifests.
SET LOCAL lock_timeout = '5s';
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM enrollments) THEN
        RAISE EXCEPTION 'Legacy enrollments remain; explicit approved cleanup required';
    END IF;
END $$;
ALTER TABLE enrollments DROP CONSTRAINT enrollments_unique_student_course;
ALTER TABLE enrollments DROP CONSTRAINT enrollments_ref_course_id;
DROP INDEX enrollments_course_id_index;
ALTER TABLE enrollments DROP COLUMN course_id;
ALTER TABLE enrollments ADD COLUMN subject_id UUID NOT NULL;
ALTER TABLE enrollments ADD CONSTRAINT enrollments_ref_subject_id FOREIGN KEY (subject_id) REFERENCES subjects(id) ON DELETE NO ACTION;
ALTER TABLE enrollments ADD CONSTRAINT enrollments_unique_student_subject UNIQUE(student_id,subject_id);
CREATE INDEX enrollments_subject_id_index ON enrollments(subject_id);
