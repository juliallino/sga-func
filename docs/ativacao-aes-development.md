# Ativação AES no Development — resultado

Branch: `sprint-4`. Base anterior: `0849cdc`. Integração local concluída, sem commit e sem push. A autorização recebida limita a migração ao banco PostgreSQL Development local; nenhuma autorização foi extrapolada para Production.

## Preservação e backup

O patch de 886 linhas foi revisado integralmente, conferido com o manifesto do pacote e aplicado após `git apply --check`. As quatro alterações locais do Reader e todos os arquivos históricos privados foram preservados. Nenhum reset, merge ou descarte foi realizado.

Um backup privado em formato custom foi criado fora do repositório, listado com `pg_restore --list` e restaurado integralmente em cluster PostgreSQL temporário. Dados, tipos de colunas, constraints e índices restaurados coincidiram com a origem. A primeira comparação incluía números físicos de colunas removidas no passado; a verificação lógica corrigida passou antes de qualquer mudança no banco. O backup e os diagnósticos privados não fazem parte da publicação.

## Banco e migração

Destino confirmado: banco `app`, socket local do cluster devenv do próprio projeto, PostgreSQL 17.10. Os serviços IHP usavam o ambiente Development padrão do IHP 1.6; após a ativação receberam `IHP_ENV=Development` explícito. Nenhum serviço Production foi alterado.

Foi aplicada exclusivamente `1793923200.sql`, em transação, com lock timeout, verificações de preservação antes do commit e registro da revisão `1793923200` em `schema_migrations`.

- Nova coluna `students.confidential_note_encrypted`: TEXT, aceita NULL, sem default.
- Não foram alterados constraints, índices ou relacionamentos.
- Os dados anteriores de estudantes, contas, professores, matrículas, notas e vínculos coincidiram integralmente após a migração e as verificações finais.
- As 10 notas confidenciais permaneceram NULL. Nenhum estudante existente foi usado para testar escrita.
- A única mudança de dados de controle foi o registro da nova revisão de migração.

| Entidade | Quantidade preservada |
|---|---:|
| Estudantes | 10 |
| Contas | 26 |
| Professores | 6 |
| Cursos | 1 |
| Disciplinas | 5 |
| Matrículas | 50 |
| Avaliações | 120 |
| Vínculos docentes | 5 |

## Chave e aplicação

A chave de 32 bytes foi gerada por fonte criptograficamente segura e persistida em arquivo externo ao Git com permissão `0600`, sob diretório privado `0700`. A configuração `.env` é ignorada pelo Git e contém somente referência ao arquivo, além dos parâmetros locais. Não contém o material da chave. Nenhum valor secreto é publicado aqui.

Os dois servidores IHP Development existentes foram reiniciados com os mesmos ambientes Nix, URLs de banco verificadas e a chave persistente, nas portas locais 8000 e 8003. Ambos responderam HTTP 200 em `/Login`; o PostgreSQL principal não foi reiniciado. Reinícios futuros devem carregar a configuração local via direnv; não gerar nova chave.

Admin possui link no detalhe do estudante para cadastrar, consultar, editar e remover a observação em HSX/SSR com o estilo roxo existente. Controllers e DAL exigem Admin antes de leitura/descriptografia/escrita. Teacher e Student recebem 403. Hash de senhas, autenticação, Reader, cálculos, dashboards e portais acadêmicos foram preservados.

## Testes executados nesta ativação

| Verificação | Resultado |
|---|---|
| Compilação IHP 1.6 / GHC 9.10.3 do código integrado | Aprovada: 136 módulos; `ghc -fno-code`, com HSX e Template Haskell |
| Domínio/segurança/Reader/CPS/Functors/lazy | 89 exemplos, 0 falhas |
| Integração | 1 exemplo, 0 falhas |
| CRUD | 53 exemplos, 0 falhas |
| Autenticação/autorização | 43 exemplos, 0 falhas |
| Vínculos docentes | 8 exemplos, 0 falhas |
| Modelo acadêmico/rankings | 13 exemplos, 0 falhas |
| Dashboards/filtros/médias | 8 exemplos, 0 falhas |
| Portais | 16 exemplos, 0 falhas |
| AES persistido | 14 exemplos, 0 falhas |
| Seed portátil em cluster separado | 10 exemplos, 0 falhas; idempotência, preservação e proteções de destino aprovadas |
| Revogação concorrente e migração aditiva isolada | PASS |
| Development principal em conexões forçadas somente leitura | 5 exemplos, 0 falhas: Admin, observação NULL, bloqueio Teacher/Student, dashboards e rankings |
| Chave persistente em dois processos independentes | PASS: cifragem de valor fictício fora do banco e recuperação por novo processo |
| Preservação integral de registros, constraints e índices principais | PASS |
| Varredura de material da chave em candidatos ao Git | PASS: nenhum valor da chave encontrado; `.env` ignorado e chave de sessão não rastreada |

Total único: **260 exemplos aprovados, 0 falhas** — 245 da regressão isolada, 10 do seed portátil em outro cluster temporário e 5 consultas somente leitura no Development principal. A revalidação prévia do pacote não foi somada outra vez. O exemplo trivial já existente na suíte não constitui cobertura adicional. Logs desta ativação ficaram em armazenamento privado fora do Git.

Os 14 testes AES comprovam persistência cifrada, recuperação Admin, edição/remoção, NULL, nonce novo, chave errada/ausente, adulteração da tag, rotação, proteção contra troca de estudante, autorização em controller e DAL, UTF-8, escape HSX e continuidade do CRUD. Todas as escritas desses testes ocorreram em cluster temporário. O valor fictício da verificação da chave não foi associado a estudante real nem gravado no banco principal.

Oito checagens visuais e a demonstração HTTP com reinício completo do cluster fictício foram aprovadas na fase isolada anterior; não foram repetidas nem somadas nesta ativação. Não foi feito teste de carga, deploy Production ou build/link otimizado de produção.

## Evidências no código principal

| Arquivo | Função / linhas |
|---|---|
| `Application/Security/FieldEncryption.hs` | `encryptField`, `decryptField`: 54–73 |
| `Application/Security/ConfidentialNote.hs` | `parseNoteKeys`: 29–46; `loadNoteKeys`: 48–54; `sealNote`: 61–68; `openNote`: 70–79 |
| `Application/Helper/ConfidentialNote.hs` | `readNote`: 16–28; `saveNote`: 30–55; `removeNote`: 57–73 |
| `Web/Controller/StudentConfidentialNotes.hs` | ações administrativas: 10–38; cabeçalhos/erros: 40–49 |
| `Web/View/StudentConfidentialNotes/Show.hs` | HSX SSR: 4–28 |
| `Web/View/Students/Show.hs` | link Admin: 19,31–32 |
| `Application/Schema.sql` | coluna opcional: 19 |
| `Application/Migration/1793923200.sql` | migração aplicada: 1–3 |
| `Test/ConfidentialNotes.hs` | teste isolado completo: 39–203 |

O detalhamento linha a linha e o histórico da fase isolada permanecem em `docs/finalizacao-sprint3-reader-e-analise-aes.md`. Configuração e operação estão em `docs/configuracao-aes-development.md`.

## Situação para publicação

O requisito de hash de senhas + criptografia de campo sensível está implementado, testado e ativo no Development. Junto do Reader já integrado e dos demais itens comprovados na auditoria, a pendência técnica da Sprint 3 foi encerrada. Isso não implica aprovação de funcionalidades opcionais pendentes da Sprint 4, como política de aprovação acadêmica ou CRUD de contas além da listagem.

O código está preparado para publicação por seleção explícita dos arquivos de `docs/publicacao-sprint4-arquivos.md`. Não usar `git add .`: existem históricos privados e artefatos locais não necessários à publicação. Nenhum arquivo foi staged, commitado ou enviado por esta ativação.
