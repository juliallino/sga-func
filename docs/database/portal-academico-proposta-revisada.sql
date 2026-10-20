-- PROPOSTA REVISADA PARA APROVACAO. NAO APLICADA.
-- Prefixo Role evita colisoes com os modelos Student e Teacher no IHP 1.6.
-- Fora de Application/Migration para impedir execucao automatica pelo IHP.
-- Depois da aprovacao: criar uma NOVA migration <timestamp>.sql no IHP 1.6.
-- O executor do IHP controla a transacao; nao incluir BEGIN/COMMIT nessa migration.
-- Conferir previamente o schema real e as revisoes aplicadas. Nao reaplicar
-- migrations antigas nem importar Application/Schema.sql em banco existente.
-- Esta etapa e aditiva: Enrollment continua vinculada ao Course original.

SET LOCAL lock_timeout = '5s';

CREATE TYPE user_role AS ENUM ('RoleAdmin', 'RoleTeacher', 'RoleStudent');

CREATE TABLE users (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    role user_role NOT NULL
);

ALTER TABLE students
    ADD COLUMN user_id UUID,
    ADD CONSTRAINT students_user_id_key UNIQUE (user_id),
    ADD CONSTRAINT students_ref_user_id
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE NO ACTION;

CREATE TABLE teachers (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY NOT NULL,
    user_id UUID UNIQUE,
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    registration_number TEXT NOT NULL UNIQUE,
    specialization TEXT,
    CONSTRAINT teachers_ref_user_id
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE NO ACTION
);

CREATE TABLE subjects (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY NOT NULL,
    course_id UUID NOT NULL,
    name TEXT NOT NULL,
    code TEXT NOT NULL UNIQUE,
    workload INT NOT NULL,
    CONSTRAINT subjects_workload_positive CHECK (workload > 0),
    CONSTRAINT subjects_ref_course_id
        FOREIGN KEY (course_id) REFERENCES courses (id) ON DELETE NO ACTION
);

CREATE INDEX subjects_course_id_index ON subjects (course_id);

-- Validacao imediata dos registros existentes. Dados invalidos fazem a
-- transacao falhar; nao sao corrigidos, removidos nem substituidos.
-- NUMERIC aceita NaN: rejeita-lo explicitamente tambem no peso.
ALTER TABLE grades
    ADD CONSTRAINT grades_score_range CHECK (score >= 0 AND score <= 10),
    ADD CONSTRAINT grades_weight_positive
        CHECK (weight > 0 AND weight <> 'NaN'::numeric);

-- Nao criar contas, senhas, professores ou disciplinas automaticamente.
-- Nao alterar courses, enrollments, os IDs ou as FKs preexistentes.
-- A conversao de Enrollment depende do mapeamento real descrito no documento.
