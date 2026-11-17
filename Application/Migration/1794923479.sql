-- Frequência por chamada (aula). Migração aditiva: cria duas tabelas novas,
-- sem alterar ou remover dados existentes.
SET LOCAL lock_timeout = '5s';
CREATE TABLE class_sessions (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY NOT NULL,
    subject_id UUID NOT NULL,
    class_date DATE NOT NULL,
    topic TEXT,
    CONSTRAINT class_sessions_ref_subject_id
        FOREIGN KEY (subject_id) REFERENCES subjects (id) ON DELETE NO ACTION
);
CREATE INDEX class_sessions_subject_id_index ON class_sessions (subject_id);
CREATE TABLE attendances (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY NOT NULL,
    class_session_id UUID NOT NULL,
    enrollment_id UUID NOT NULL,
    present BOOLEAN NOT NULL,
    CONSTRAINT attendances_unique_session_enrollment
        UNIQUE (class_session_id, enrollment_id),
    CONSTRAINT attendances_ref_class_session_id
        FOREIGN KEY (class_session_id) REFERENCES class_sessions (id) ON DELETE NO ACTION,
    CONSTRAINT attendances_ref_enrollment_id
        FOREIGN KEY (enrollment_id) REFERENCES enrollments (id) ON DELETE NO ACTION
);
CREATE INDEX attendances_enrollment_id_index ON attendances (enrollment_id);
