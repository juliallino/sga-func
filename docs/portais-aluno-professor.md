# Portais do aluno e do professor — Sprint 4

Os portais reutilizam HSX/SSR, o layout roxo, as sessões nativas IHP 1.6 e as
verificações de identidade/perfil existentes. Não há novo mecanismo de login,
modelo de avaliação, migração, seed ou alteração de dados do Development.

## Rotas e acesso

| Perfil | Rotas |
| --- | --- |
| Admin | `/` e os CRUDs/vínculos administrativos existentes |
| Aluno | `/StudentDashboard`, `/MySubjects`, `/Grades`, `/MyAverages`, `/MyProfile`, `/Rankings` |
| Professor | `/TeacherDashboard`, `/Subjects`, `/TeacherStudents`, `/TeacherGradeEntry`, `/TeacherAssessments`, `/TeacherProfile`, `/Rankings` |
| Professor por disciplina | `/TeacherSubjectStudents?subjectId=UUID`, `/TeacherSubjectAssessments?subjectId=UUID` |
| Lançamento contextual | `/NewGrade?subjectId=UUID`, opcionalmente `&enrollmentId=UUID` |

Após login, a sessão nativa redireciona para o painel do perfil. As rotas de
portais exclusivos rejeitam outros perfis. Rotas compartilhadas, como notas,
matrículas, disciplinas e rankings, aplicam o escopo autorizado do usuário.
A concessão e revogação de `teacher_subjects` continuam exclusivas do Admin.

## Aluno

O dashboard mostra nome, matrícula, disciplinas, avaliações, média geral por
curso quando completa e indicadores de classificação quando houver critério.
Não se mistura o desempenho de cursos distintos. A regra da média geral é a
mesma já usada no projeto: média simples das médias ponderadas de todas as
disciplinas do curso, cada disciplina com contribuição igual. Se uma disciplina
não tem matrícula/média, o resultado geral permanece indisponível.

Minhas disciplinas informa código, curso, docentes efetivamente atribuídos,
situação da matrícula, média atual e situação acadêmica. Vários professores
podem ser apresentados e a ausência de vínculo é explicitada. Minhas notas
apresenta as avaliações, notas, pesos e média ponderada de cada matrícula.
O perfil continua somente leitura. Não há atalhos de criação/edição de notas
nem de matrícula para o aluno; as escritas também são recusadas pelo servidor.

## Professor

O dashboard mantém as contagens reais de disciplinas, estudantes distintos e
avaliações do escopo docente e acrescenta um resumo por disciplina. A média
atual da turma é a média simples das médias ponderadas disponíveis, com uma
contribuição por matrícula. Não trata ausência como zero e não cria média
global entre turmas. A métrica é descritiva e pode refletir avaliações parciais.

As listas de disciplinas e os fluxos de consulta/lançamento usam atribuições
explícitas. A lista de matriculados acrescenta e-mail, média e situação acadêmica.
Os links mantêm disciplina e matrícula na abertura do formulário. Contextos
inválidos ou não autorizados são recusados, sem ampliar as opções do formulário.

Cadastro e edição de notas continuam em `GradesController`: validações puras
existentes, verificações no servidor e transação com bloqueio do vínculo docente.
Um professor não pode mover uma avaliação para outra matrícula nem escrever em
outra disciplina. A exclusão de avaliações continua exclusiva do Admin.

## Aprovação: pendência acadêmica explícita

O repositório não define média mínima oficial nem condição de fechamento das
avaliações. `filtrarNotasAprovadas` recebe um limite como parâmetro; os valores
usados em exemplos/testes não constituem política institucional. O documento
`APRESENTACAO_FUNCIONAL.md` já distingue esse exemplo de uma regra de aprovação.

Por isso `approvalPolicy`, em `Application/Domain/Academic.hs`, permanece
`Nothing`. Os contadores de aprovados, pendentes e desempenho insuficiente
mostram `—`, com aviso explícito. Não se presume que matrícula `completed`
signifique aprovação nem que notas parciais sejam resultados finais.

A estrutura pura aceita uma política explícita para que os critérios aprovados
possam ser integrados depois: limite de média e exigência ou não de matrícula
concluída. Nenhum limite foi ativado nesta entrega. Ausência/invalidade de média
continua representada por `Nothing`. Notas e pesos usam as validações existentes.

## Separação de responsabilidades

- `Application/Domain/Academic.hs`: média completa existente, resumo descritivo e
  classificação somente com política explícita; sem IO.
- `Application/Helper/Portal.hs`: projeções dos registros já autorizados; bateladas
  de cursos/docentes e médias delegadas ao domínio existente.
- `Web/Controller/Static.hs` e `Grades.hs`: autorização, consultas e seleção de
  contexto; médias são preparadas antes da renderização.
- `Web/View/Portal/Academic.hs`: apresentação compartilhada de métricas e estados.
- Views StudentPortal/TeacherPortal: navegação e conteúdo próprios de cada perfil.

## Verificação reproduzível

No ambiente IHP/Nix:

```sh
runghc -ignore-dot-ghci -XBlockArguments -i. Test/Main.hs
python3 Test/run-crud-tests.py --skip-migrations
```

O executor acrescenta `Test/Portals.hs` às suítes existentes e escreve somente
em PostgreSQL temporário isolado. Os testes cobrem redirecionamentos, dados
próprios, metadados, médias, curso incompleto, ausência de docente/notas, perfis
cruzados, URLs externas, criação/edição de notas, validação, permissões e Admin.

Para exportar amostras SSR exclusivamente fictícias para inspeção visual:

```sh
mkdir -p /tmp/sga-portals-ssr
SGA_PORTAL_SNAPSHOTS=/tmp/sga-portals-ssr python3 Test/run-crud-tests.py --skip-migrations
```

Os HTMLs exportados não devem ser adicionados ao Git. Não é necessário conectar
ao banco atual ou executar o seed da demonstração para testar os portais.

## Resultado da validação desta entrega

- Main.hs e dependências: 121 módulos, incluindo HSX, com GHC -fno-code e IHP 1.6.
- Domínio e segurança: 83 exemplos, nenhuma falha.
- Integração, CRUD, autenticação, vínculos, modelo acadêmico, dashboards e novos
  portais: 141 exemplos, nenhuma falha (16 novos casos de portais).
- Demonstração em outro cluster temporário: 10 exemplos, nenhuma falha; todos
  os nomes/e-mails publicados e os três perfis exercitados.
- Firefox headless: 12 amostras SSR fictícias em 1440, 768, 390 e 320 px,
  totalizando 48 verificações sem transbordamento horizontal da página;
  tabelas usam rolagem interna; menu móvel e Escape passaram.
- Total Hspec: 234 exemplos, nenhuma falha.

As falhas iniciais de compilação/testes foram corrigidas antes desses resultados.
Nenhuma correção exigiu modificar schema, migrações, seeds, autenticação ou dados
reais. O código de escrita existente foi reutilizado e continuou protegido pelos
bloqueios/validações originais. Não foi realizado commit ou push.
