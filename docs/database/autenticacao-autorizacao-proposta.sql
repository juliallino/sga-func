-- PROPOSTA PENDENTE DE APROVACAO. NAO APLICAR AUTOMATICAMENTE.
-- Depois da aprovacao, criar NOVA migration timestamp.sql do IHP 1.6.
-- O executor IHP controla a transacao. Nao reaplicar o historico antigo.

SET LOCAL lock_timeout = '5s';

-- Campos usados pelo createSessionAction nativo do IHP 1.6 para bloqueio
-- temporario por tentativas invalidas. Nao altera hashes, roles ou IDs.
ALTER TABLE users ADD COLUMN failed_login_attempts INT NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN locked_at TIMESTAMP WITH TIME ZONE;

-- Um vinculo significa permissao para consultar a disciplina e seus alunos
-- e criar/editar avaliacoes das matriculas comprovadamente nessa disciplina.
-- Apenas Admin pode conceder ou revogar esses vinculos.
CREATE TABLE teacher_subjects (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY NOT NULL,
    teacher_id UUID NOT NULL,
    subject_id UUID NOT NULL,
    CONSTRAINT teacher_subjects_unique_teacher_subject
        UNIQUE (teacher_id, subject_id),
    CONSTRAINT teacher_subjects_ref_teacher_id
        FOREIGN KEY (teacher_id) REFERENCES teachers (id) ON DELETE NO ACTION,
    CONSTRAINT teacher_subjects_ref_subject_id
        FOREIGN KEY (subject_id) REFERENCES subjects (id) ON DELETE NO ACTION
);

-- UNIQUE ja cobre buscas por teacher_id; indice separado para subject_id.
CREATE INDEX teacher_subjects_subject_id_index ON teacher_subjects (subject_id);

-- Nao cria contas, senhas ou permissoes; nao migra matriculas por curso.
