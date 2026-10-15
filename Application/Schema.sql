CREATE TABLE students (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    enrollment_number TEXT NOT NULL UNIQUE
);

-- 4. Tabela de cursos
CREATE TABLE courses (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    code TEXT NOT NULL UNIQUE,
workload INT NOT NULL);

-- 5. Tipo para situação da matrícula
CREATE TYPE enrollment_status AS ENUM (
    'active',
    'suspended',
    'completed'
);

-- 6. Tabela de matrículas
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

-- 7. Índices das matrículas
CREATE INDEX enrollments_student_id_index
    ON enrollments (student_id);

CREATE INDEX enrollments_course_id_index
    ON enrollments (course_id);

-- 8. Tabela de notas
CREATE TABLE grades (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY NOT NULL,
    enrollment_id UUID NOT NULL,
    assessment_name TEXT NOT NULL,
    score NUMERIC(5,2) NOT NULL,
    weight NUMERIC(5,2) NOT NULL,

    CONSTRAINT grades_ref_enrollment_id
        FOREIGN KEY (enrollment_id)
        REFERENCES enrollments (id)
        ON DELETE NO ACTION
);
-- 9. Índice das notas
CREATE INDEX grades_enrollment_id_index
    ON grades (enrollment_id);