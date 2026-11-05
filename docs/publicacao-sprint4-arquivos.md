# Arquivos para publicação da Sprint 4

A integração AES está ativa e testada no Development. Esta lista distingue o código necessário dos arquivos privados/históricos já existentes. Nada foi adicionado ao índice, commitado ou enviado. Não usar `git add .`.

## Seleção recomendada

Inclui as alterações Reader já existentes, a integração AES, a migração, testes e documentação operacional. Revisar os arquivos explicitamente antes de adicionar ao índice:

- `.env.example`.
- `App.cabal`.
- `Application/Domain/AcademicConfig.hs`.
- `Application/Domain/ConfidentialNote.hs`.
- `Application/Helper/ConfidentialNote.hs`.
- `Application/Migration/1793923200.sql`.
- `Application/Schema.sql`.
- `Application/Security/ConfidentialNote.hs`.
- `Application/Security/FieldEncryption.hs`.
- `Test/CRUD.hs`.
- `Test/ConfidentialNoteDemo.hs`.
- `Test/ConfidentialNotes.hs`.
- `Test/Domain/ConfidentialNoteSpec.hs`.
- `Test/Domain/MonadsSpec.hs`.
- `Test/Main.hs`.
- `Test/check-confidential-note-migration.py`.
- `Test/check-migrations.py`.
- `Test/run-confidential-note-demo.py`.
- `Test/run-confidential-note-tests.py`.
- `Test/run-crud-tests.py`.
- `Web/Controller/Grades.hs`.
- `Web/Controller/StudentConfidentialNotes.hs`.
- `Web/FrontController.hs`.
- `Web/Routes.hs`.
- `Web/Types.hs`.
- `Web/View/StudentConfidentialNotes/Show.hs`.
- `Web/View/Students/Show.hs`.
- `docs/ativacao-aes-development.md`.
- `docs/configuracao-aes-development.md`.
- `docs/execucao-aes-isolada.md`.
- `docs/publicacao-sprint4-arquivos.md`.
- `flake.nix`.

## Manter fora da seleção automática

- `.env`, `Config/client_session_key.aes`, o arquivo privado de chaves e os backups PostgreSQL: nunca publicar; permanecem ignorados ou fora do repositório.
- `Test/RehearsalChecks.hs`, `docs/apresentacao/` e arquivos não rastreados de `docs/database/`: trabalhos locais/históricos preservados, sem inclusão nesta seleção.
- `docs/isolado-aes-evidencias/`, o patch, manifesto e arquivo tar da fase isolada: artefatos locais de auditoria; o código já está integrado, não são necessários à execução.
- `docs/auditoria-sprints-3-e-4.md`, `docs/finalizacao-sprint3-reader-e-analise-aes.md` e `docs/seguranca-sprint3.md`: relatórios locais/históricos preservados, cuja publicação pode ser decidida separadamente após revisão.

A varredura verificou que o material da chave AES provisionada não aparece nos candidatos ao Git. O `.env` local contém referência ao arquivo externo, sem o valor da chave, e continua ignorado. Isso não substitui a revisão dos trabalhos privados anteriores antes de uma eventual publicação deles.

## Estado do banco

A migração 1793923200 já foi aplicada ao Development desta instalação. Sua presença no commit serve à rastreabilidade e a outras instalações com autorização própria; não reaplicá-la no banco atual. Production não foi alterado.
