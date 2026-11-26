-- Períodos letivos (2026.1, 2026.2...). Migração aditiva: matrículas
-- existentes ficam sem período (academic_period_id NULL) e nada é apagado.
SET LOCAL lock_timeout = '5s';
CREATE TABLE academic_periods (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY NOT NULL,
    name TEXT NOT NULL UNIQUE,
    starts_on DATE NOT NULL,
    ends_on DATE NOT NULL,
    CONSTRAINT academic_periods_dates_order CHECK (ends_on > starts_on)
);
ALTER TABLE enrollments ADD COLUMN academic_period_id UUID;
ALTER TABLE enrollments ADD CONSTRAINT enrollments_ref_academic_period_id
    FOREIGN KEY (academic_period_id) REFERENCES academic_periods (id) ON DELETE NO ACTION;
CREATE INDEX enrollments_academic_period_id_index ON enrollments (academic_period_id);
-- A unicidade passa a ser por período, para permitir refazer a disciplina.
-- O índice novo é criado antes de remover o antigo: nunca há janela sem regra.
CREATE UNIQUE INDEX enrollments_unique_student_subject_period
    ON enrollments (student_id, subject_id, academic_period_id) NULLS NOT DISTINCT;
ALTER TABLE enrollments DROP CONSTRAINT enrollments_unique_student_subject;
