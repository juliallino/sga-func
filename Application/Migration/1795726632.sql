-- Situação "Inativa" para matrículas desativadas. Migração aditiva: só
-- acrescenta um valor ao tipo; nenhuma linha existente é alterada.
ALTER TYPE enrollment_status ADD VALUE IF NOT EXISTS 'inactive';
