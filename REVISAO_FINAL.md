# Revisão final do SGA — Portal Acadêmico Simples

Revisão executada em 19/10/2026. Haskell, IHP 1.6 e PostgreSQL 17.10 local.

**Resultado:** aplicação compilada e testes executados com sucesso após a
correção de um erro de validação numérica. O portal ainda possui pendências
funcionais descritas abaixo; a migração para matrículas por disciplina não
está concluída. Não foi feito reset, exclusão ou alteração de dados reais.

## 1. Funcionalidades verificadas

| Módulo | Verificação executada | Resultado e limite |
| --- | --- | --- |
| Estudantes | Criar, listar, detalhes, editar, excluir; campos inválidos; e-mail/matrícula duplicados; dependências | Passou em banco temporário; alterações somente Admin |
| Professores | CRUD; especialização opcional; e-mail e registro únicos; exclusão com autorização e preservação de conta | Passou em banco temporário |
| Cursos | CRUD; código único; carga positiva; exclusão com matrícula ou disciplina | Passou em banco temporário |
| Disciplinas | CRUD; código único; carga positiva; curso obrigatório/existente; exclusão com autorização | Passou em banco temporário |
| Matrículas | CRUD, status, referências, duplicidade estudante/curso, data automática e preservada na edição | Passou; ainda usa Course, não Subject |
| Avaliações | CRUD, matrícula existente, nota 0–10, peso positivo/finito e compatível com NUMERIC(5,2) | Passou; escritas continuam Admin-only |
| Média ponderada | Decimais, pesos, limites, vazio, inválidos, NaN/infinito e overflow; apresentação por matrícula | Passou; mesmo domínio puro |
| Login/logout | Senha válida/inválida, cookie, logout por POST e acesso após logout | Passou pelo fluxo HTTP real em banco temporário |
| Bloqueio de login | Dez falhas, contador, locked_at e rejeição da senha correta enquanto bloqueado | Passou em banco temporário |
| Student | Perfil próprio, listagens próprias, notas/médias, UUID de terceiros e tentativa de escrita | Passou; perfil precisa de students.user_id válido |
| Teacher | Apenas disciplinas de teacher_subjects; revogação; bloqueio de dados/notas legados e alterações não permitidas | Passou; sem autorização inferida por curso |
| Admin | CRUDs, visão administrativa e consulta de contas | Passou; contas ainda não têm CRUD de gestão |
| Dashboard | Contagens obtidas do PostgreSQL e menu por perfil | Passou; nenhuma contagem fictícia |
| Usuários | Consulta restrita ao Admin e ausência de senha/hash na resposta | Passou; criação/edição/exclusão de contas não implementadas |

### Banco real: inspeção somente de leitura

Foram consultados catálogos, colunas, defaults, PKs, FKs, índices, constraints,
enums, revisões e contagens em transações `READ ONLY`. As oito tabelas de negócio
possuem PK UUID. As FKs esperadas estão presentes e validadas, sem exclusões em
cascata; `schema_migrations` registra as revisões executadas.

| Tabela | Linhas na auditoria |
| --- | ---: |
| users | 1 |
| students | 1 |
| teachers | 0 |
| courses | 1 |
| subjects | 0 |
| enrollments | 1 |
| grades | 0 |
| teacher_subjects | 0 |

São dados observados, não dados de demonstração inseridos nesta revisão.

Quinze verificações retornaram zero violações: oito verificações de referências
órfãs, duas de pares duplicados, validade de notas/pesos, cargas de cursos e
disciplinas, e compatibilidade de perfil das contas vinculadas a Student/Teacher.
Algumas tabelas estão vazias: a inspeção real não substitui os testes com dados
no banco temporário.

As auditorias antes/depois foram idênticas, incluindo estrutura, contagens,
revisões, integridade e assinaturas dos registros acadêmicos. Hashes de senha
não foram impressos ou incluídos neste relatório.

### Migrações e relacionamentos

- Aplicadas no banco real: **1792451864** e **1792459225**.
- Em teste isolado, as duas migrations foram executadas sobre uma baseline
  de quatro tabelas com estudante, curso, matrícula histórica e avaliação.
- IDs, valores, data, status e grade.enrollment_id permaneceram idênticos.
- Colunas, tipos/precisão, defaults, nulabilidade, constraints, enums e índices
  do banco migrado coincidiram com os de um banco criado pelo schema atual.
  A ordem física de colunas foi desconsiderada, pois ADD COLUMN anexa user_id.
- Uma segunda execução do executor não reaplicou as migrations nem mudou dados.
- As migrations antigas não foram executadas. Contêm remoções de dados e o
  default inválido `'Active'`; não foi afirmado que a cadeia histórica completa
  funciona sobre um banco vazio.
- A migration 1792029677 não foi aplicada ao banco real porque suas constraints
  já estavam presentes. Não foi registrada falsamente como executada.
- Neste banco, futuras execuções de migrations devem manter
  `MINIMUM_REVISION=1792029677`. Outro banco exige análise de sua baseline.

O schema não possui CHECK de carga positiva em courses: essa regra é validada
pelo CRUD. NOT NULL não impede texto vazio; validações de texto estão na aplicação.
Não foram adicionadas constraints ao banco real sem uma migration aprovada.

### Programação funcional

Confirmados os 13 conceitos de APRESENTACAO_FUNCIONAL.md: tipos algébricos,
records imutáveis, funções puras, média ponderada, predicados de validação,
closure, currying/aplicação parcial, list comprehensions, pattern matching,
map, filter, foldl e concatMap.

Application/Domain/Grade.hs continua importando apenas Prelude, sem banco ou IO.
Controllers adaptam dados autorizados; views apresentam resultados. Bônus,
filtragem por limite e duplicação de notas são demonstrações didáticas existentes,
não novas regras de aprovação ou alterações automáticas das notas.

## 2. Testes executados

| Execução | Resultado |
| --- | --- |
| GHC com extensões do IHP 1.6, `-fno-code`, Main.hs | 105 módulos compilados |
| Test/Main.hs | 16 exemplos, 0 falhas |
| Test/Integration.hs | 1 exemplo, 0 falhas |
| Test/CRUD.hs | 52 exemplos, 0 falhas |
| Test/Auth.hs | 22 exemplos, 0 falhas |
| Test/check-migrations.py, acionado pelo executor isolado | Cenário de preservação, equivalência de schema e reexecução passou |
| Comandos extraídos de APRESENTACAO_FUNCIONAL.md | 35 comandos GHCi e respectivas saídas conferidos |
| Examples/Grade.hs | Executado; saídas correspondentes aos exemplos |
| JavaScript | `node --check static/app.js` passou |
| Python | Sintaxe dos dois executores conferida |
| Whitespace | `git diff --check` passou |

**Total: 91 exemplos Hspec sem falhas**, mais o cenário de migrations e os
35 comandos GHCi. Todas as escritas de teste ocorreram no PostgreSQL temporário,
com socket exclusivo em /tmp e TCP desabilitado, sem usar o DATABASE_URL real.
Os arquivos temporários são retidos e o servidor de teste é encerrado.

Também foram feitas requisições de leitura ao servidor real em localhost:8000:

- GET /Login: 200.
- GET /, /Students e /Users, sem sessão: 302 para /Login.
- GET /Logout: 404, conforme esperado (logout é POST).
- GET /TeacherSubjects: 404, confirmando a pendência da tela de gestão.

Não foi feito login com a conta real nesta revisão para evitar alterações dos
contadores de sessão/tentativas. Login e logout autenticados foram executados
nos testes isolados, com contas exclusivas desse ambiente.

Não executados nesta revisão: `nix flake check`, GitHub Actions remoto, deploy,
testes de carga/concorrência e uma nova revisão visual completa no navegador.
Dois avisos de depreciação de `sqlQuery` nos testes existentes não impedem
compilação nem execução. Não são erros de autorização ou de média.

## 3. Resultados

A compilação e as suítes executadas passaram após as correções. Foram
exercitados cadastros válidos e inválidos, duplicidades, FKs, exclusões com
dependências, média e estados sem avaliações, login/logout, bloqueio por
tentativas, restrições por perfil e manipulação de identificadores/campos.
Os testes de teacher_subjects conferem os SQLSTATE 23505 (duplicidade) e 23503
(FK), para não confundir erros de consulta com aplicação efetiva das constraints.

O banco real permaneceu preservado. Não houve reset, migration aplicada,
backfill, promoção de perfil ou modificação de conta nesta revisão.

## 4. Problemas encontrados e correções

1. **Peso positivo que falhava ao gravar:** `0.001` passava no predicado de
   positividade, mas NUMERIC(5,2) arredondava para 0.00, violando o CHECK.
   O teste reproduziu uma exceção de gravação. Peso 1000 também excede a coluna.
   Adicionada validação de representabilidade, reproduzindo o arredondamento
   positivo do PostgreSQL. As entradas inválidas retornam formulário com erro,
   sem tentar gravar. Casos já armazenáveis foram preservados e testados:
   0.005 -> 0.01 e 999.994 -> 999.99. Não houve alteração na média pura.
2. **Mensagem de duplicidade incompatível com o modelo atual:** a matrícula
   é por curso, mas a mensagem dizia disciplina. Corrigida para curso.
3. **Executor dependente de um layout específico dos recursos IHP:** resolução
   de IHPSchema.sql e applicationGhciConfig agora aceita a organização do
   pacote IHP 1.6 instalado. O teste foi executado com seu data root real,
   sem depender do diretório auxiliar /tmp usado em revisões anteriores.
4. **Documentação desatualizada:** o README ainda dizia que as rotas eram
   públicas e não havia autenticação. Atualizados estado, testes e inicialização.
5. **Cobertura insuficiente de migrations e bloqueio por tentativas:** adicionados
   testes executáveis. Nenhum erro no mecanismo nativo de login foi identificado.

## 5. Arquivos modificados nesta revisão

- Web/Controller/Grades.hs: validação do peso para armazenamento.
- Web/Controller/Enrollments.hs: mensagem de duplicidade.
- Test/CRUD.hs: regressão de limites e arredondamento de pesos.
- Test/Auth.hs: bloqueio após dez falhas e integridade de teacher_subjects.
- Test/run-crud-tests.py: resolução de recursos, integração e migrations.
- Test/check-migrations.py: novo verificador isolado das migrations aditivas.
- Test/Fixtures/PrePortalSchema.sql: nova baseline exclusiva para testes.
- README.md: estado real, execução e limites atuais.
- APRESENTACAO_FUNCIONAL.md: resultados atualizados e validação de persistência.
- REVISAO_FINAL.md: este relatório.

Os arquivos já modificados em etapas anteriores continuam no workspace; a lista
acima descreve somente esta revisão. Nenhuma migration ou schema ativo foi alterado.

## 6. Como iniciar e testar

Na raiz do projeto, com Nix e direnv instalados:

```bash
direnv allow
direnv exec . ./start
```

Aguardar o ambiente carregar e o IHP informar a inicialização. A aplicação
fica em http://localhost:8000/Login e o IDE local em http://localhost:8001.
Usar a conta previamente cadastrada; não há credencial administrativa fixa no
código. Se os serviços já estiverem ativos, usar a instância existente em vez de
iniciar uma segunda sobre o mesmo cluster/portas.

No ambiente IHP carregado, para repetir os testes sem tocar no banco real:

```bash
python3 Test/run-crud-tests.py
runghc -XBlockArguments Test/Main.hs
runghc -i. Examples/Grade.hs
node --check static/app.js
```

O script de teste não importa o Schema.sql no banco real. Não usar comandos
de reset nem reaplicar migrations antigas para iniciar o sistema.

## 7. Pendências reais

1. **Enrollment -> Subject:** ainda falta o mapeamento real da matrícula antiga
   para disciplina; o banco real continua sem disciplinas cadastradas. Não
   inventar disciplinas, mover notas arbitrariamente ou substituir IDs.
2. **Professor:** consulta apenas disciplinas autorizadas. Acesso a estudantes
   e lançamento/edição de avaliações por disciplina permanecem bloqueados
   enquanto não existir vínculo comprovado da matrícula com Subject.
3. **Student / Minhas disciplinas:** a página explica os vínculos por curso;
   não há listagem efetiva de disciplinas matriculadas enquanto faltar a migração.
   Notas, médias e perfil próprios funcionam quando user_id está vinculado.
4. **Contas e vínculos:** /Users é consulta. Novo/editar/excluir usuário não são
   implementados; TeacherSubjectsController não está registrado nem implementado.
   Ainda faltam gestão Admin de permissões e vínculos de contas aos perfis.
5. **Migrações históricas:** a cadeia antiga não é uma instalação limpa válida;
   preservar o filtro/baseline e preparar uma estratégia separada para outros bancos.
6. **CI e produção:** as suítes específicas de CRUD/auth/migrations não estão no
   workflow remoto atual. Deploy ainda é um template, inclusive segredo de sessão
   de exemplo em Config/nix/hosts/production/configuration.nix. Produção não foi
   validada nesta revisão.
7. **Concorrência:** o banco protege unicidade e referências, mas não foram
   exercitadas corridas entre validação e gravação; tratamento amigável dessas
   exceções concorrentes fica como melhoria futura.

Essas pendências não foram encobertas por botões liberados, autorização por curso,
dados fictícios, migrations automáticas ou afirmações de funcionalidades completas.
