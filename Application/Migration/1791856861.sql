-- =====================================================
-- SGA-Func: Correções da estrutura do banco
-- =====================================================

-- 1. Ajustar a tabela courses
ALTER TABLE courses
    RENAME COLUMN title TO name;

ALTER TABLE courses
    DROP COLUMN IF EXISTS created_at;

ALTER TABLE courses
    ADD COLUMN IF NOT EXISTS workload INT;

-- 2. Remover a tabela antiga, caso exista
DROP TABLE IF EXISTS erollments CASCADE;

-- 3. Ajustar a tabela grades
ALTER TABLE grades
    RENAME COLUMN student_id TO enrollment_id;

ALTER TABLE grades
    RENAME COLUMN subject_name TO assessment_name;

ALTER TABLE grades
    DROP COLUMN IF EXISTS score;

ALTER TABLE grades
    DROP COLUMN IF EXISTS weight;

ALTER TABLE grades
    DROP COLUMN IF EXISTS created_at;

ALTER TABLE grades
    ADD COLUMN score NUMERIC(5,2);

ALTER TABLE grades
    ADD COLUMN weight NUMERIC(5,2);

-- 4. Ajustar a tabela students
ALTER TABLE students
    DROP COLUMN IF EXISTS course_id;

ALTER TABLE students
    DROP COLUMN IF EXISTS created_at;

ALTER TABLE students
    ADD COLUMN enrollment_number TEXT;

-- 5. Remover índices antigos, se existirem
DROP INDEX IF EXISTS erollments_course_id_index;
DROP INDEX IF EXISTS erollments_student_id_index;
DROP INDEX IF EXISTS grades_student_id_index;
DROP INDEX IF EXISTS students_course_id_index;

-- 6. Remover restrições antigas, se existirem
ALTER TABLE grades
    DROP CONSTRAINT IF EXISTS grades_ref_student_id;

ALTER TABLE students
    DROP CONSTRAINT IF EXISTS students_course_id_fkey;

-- 7. Criar restrições de unicidade
ALTER TABLE students
    ADD CONSTRAINT students_email_key UNIQUE (email);

ALTER TABLE students
    ADD CONSTRAINT students_enrollment_number_key
    UNIQUE (enrollment_number);

ALTER TABLE courses
    ADD CONSTRAINT courses_code_key UNIQUE (code);

-- 8. Criar o tipo de situação da matrícula
CREATE TYPE enrollment_status AS ENUM (
    'active',
    'suspended',
    'completed'
);

-- 9. Criar a tabela de matrículas
CREATE TABLE enrollments (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY NOT NULL,
    student_id UUID NOT NULL,
    course_id UUID NOT NULL,
    enrollment_date DATE NOT NULL DEFAULT CURRENT_DATE,
    status enrollment_status NOT NULL DEFAULT 'active',

    CONSTRAINT enrollments_unique_student_course
        UNIQUE (student_id, course_id),

    CONSTRAINT enrollments_ref_student_id
        FOREIGN KEY (student_id)
        REFERENCES students (id)
        ON DELETE NO ACTION,

    CONSTRAINT enrollments_ref_course_id
        FOREIGN KEY (course_id)
        REFERENCES courses (id)
        ON DELETE NO ACTION
);

-- 10. Criar índices
CREATE INDEX enrollments_student_id_index
    ON enrollments (student_id);

CREATE INDEX enrollments_course_id_index
    ON enrollments (course_id);

CREATE INDEX grades_enrollment_id_index
    ON grades (enrollment_id);