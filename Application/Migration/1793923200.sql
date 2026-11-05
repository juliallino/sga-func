-- Additive only. Apply to isolated test databases until separately authorized.
SET LOCAL lock_timeout = '5s';
ALTER TABLE students ADD COLUMN confidential_note_encrypted TEXT;
