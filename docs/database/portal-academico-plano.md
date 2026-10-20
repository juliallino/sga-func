# Estado atual — etapa aditiva aplicada em 19/10/2026

A revisao `1792451864` foi aplicada ao banco local `app`, pelo executor de
migrations do IHP 1.6, depois da aprovacao do SQL revisado.

- Criados users, teachers, subjects e user_role com RoleAdmin, RoleTeacher,
  RoleStudent (prefixo necessario para compilar os modelos no IHP 1.6).
- Adicionado students.user_id opcional, unico e com FK.
- Adicionadas constraints de intervalo de nota e peso positivo sem NaN.
- Todas as constraints anteriores foram preservadas.
- As quatro tabelas originais continuam com um registro cada. Assinaturas
  calculadas antes/depois confirmaram a preservacao de todos os campos
  preexistentes, inclusive IDs e relacionamentos.
- As tres tabelas novas estao vazias. Nenhuma conta, senha, disciplina ou
  associacao ficticia foi criada.
- Backup restaurado e migration validada em banco separado:
  /tmp/sga-before-portal-1792451864.dump e
  sga_portal_validation_1792451864.
- Schema atualizado e modelos regenerados com IHP_RELATION_SUPPORT=0.
- Os 32 testes CRUD/integridade e os 16 testes de dominio/Main passaram.
  O CRUD usou PostgreSQL temporario. O teste
  que gravava nota 11 diretamente passou a exigir rejeicao pela constraint.

Comando utilizado, apenas para documentacao (nao reexecutar o historico):

```bash
DATABASE_URL='postgresql:///app?host=/run/user/1000/devenv-1cd63ce/postgres' MINIMUM_REVISION=1792029677 .devenv/profile/bin/migrate
```

O banco nao tinha schema_migrations; o executor criou a tabela e registrou
somente 1792451864. As migrations antigas nao foram executadas nem marcadas
falsamente como aplicadas. Neste banco, futuras execucoes do executor devem
manter MINIMUM_REVISION=1792029677 para nao tentar reaplicar o historico
incompativel. Em outro banco, conferir o estado e definir a linha de base
adequada antes de executar migrations.

A conversao Enrollment.course_id -> Subject permanece BLOQUEADA ate receber
mapeamento real. A aplicacao continua usando matriculas por curso. Login,
autorizacao e CRUDs novos nao fazem parte desta etapa de banco.

Os arquivos de proposta/candidato/bloqueada sao historicos de revisao; a
fonte ativa agora e Application/Schema.sql e Application/Migration/1792451864.sql.

---

# Proposta de evolucao do banco — pendente de aprovacao

Nenhum SQL deste plano foi aplicado. O arquivo `portal-academico-proposta.sql`
contem apenas a etapa aditiva proposta, nao a conversao completa das matriculas.
Ele fica fora de `Application/Migration/` para nao ser executado automaticamente.
O schema ativo e os modelos gerados permanecem inalterados ate a aprovacao.

## Historico e precondicoes

- `1791856861.sql`: possui remocoes de tabela/colunas e nao deve ser reaplicada.
- `1791858728.sql`: remove FKs/unicidade e usa default `Active`, incompativel
  com o enum de matricula declarado em minusculas.
- `1791901766.sql`: corrige o default para `active`.
- `1792029677.sql`: restaura FKs/unicidade; nao presumir que esteja aplicada.

Antes da execucao, consultar somente em leitura as revisoes aplicadas,
`pg_constraint`, colunas, tipos, referencias orfas, duplicidades e notas/pesos
invalidos. Preparar backup e validar a restauracao. Nao executar o historico
inteiro nem importar o schema atual sobre o banco existente. Se houver
divergencias, preparar uma migration especifica para o estado constatado.

As novas migrations devem ser arquivos SQL com timestamp em
`Application/Migration/`, usando o executor transacional do IHP 1.6. Nao editar
migrations antigas. Executar somente depois de aprovacao do SQL definitivo.

## Etapa aditiva proposta

Cria `users`, `teachers`, `subjects` e `user_role` com os valores solicitados.
Acrescenta `students.user_id`, opcional e unico quando preenchido. UNIQUE do
PostgreSQL permite varios NULLs. Nao preenche contas nem hashes ficticios.
Mantem os dados duplicados de nome/e-mail explicitamente solicitados para
User e perfis; a politica futura de sincronizacao depende da aplicacao.

Mantem Course e o enum de matricula existentes. Acrescenta CHECKs de nota e
peso, sem alterar valores existentes. Se houver dados invalidos, a transacao
deve falhar e aguardar decisao sobre esses registros. Nao usar NOT VALID para
declarar concluida uma validacao ainda pendente.

Nao foi adicionado teacher_id a Subject: esse relacionamento nao consta da
estrutura solicitada e precisa de definicao antes de ampliar o modelo.

## Conversao de matriculas: interrompida por falta de mapeamento

Uma matricula antiga identifica estudante e curso, sem identificar disciplina.
As notas tambem nao possuem essa informacao: assessment_name e o nome de uma
avaliacao, nao uma identificacao confiavel de disciplina. Nao e seguro criar
uma disciplina com o nome do curso ou replicar notas entre disciplinas.

E necessario fornecer disciplinas reais (curso, nome, codigo, carga horaria)
e um mapeamento de cada enrollment.id antigo para um subject.id real. Mesmo
um curso com apenas uma disciplina requer validacao semantica desse vinculo.
Se uma matricula representar varias disciplinas, sera necessario tambem
identificar a disciplina de cada grade.id antes de decidir como dividir os
vinculos preservando os IDs existentes. Esse caso exige um plano adicional.

A futura migration deve, em uma unica transacao:

1. Bloquear escritas concorrentes durante a conversao e validar novamente os dados.
2. Adicionar subject_id inicialmente opcional, com FK e indice.
3. Carregar somente o mapeamento aprovado e verificar cobertura de todas as
   matriculas, existencia das disciplinas e igualdade entre curso original e
   subjects.course_id. Interromper se houver lacunas ou inconsistencias.
4. Preencher subject_id sem alterar enrollment.id ou grade.enrollment_id.
5. Validar UNIQUE(student_id, subject_id) e tornar subject_id NOT NULL.
6. Preservar o vinculo original em uma tabela de historico
   enrollment_course_origins (enrollment_id PK/FK, course_id FK), copiando
   exatamente os IDs existentes e verificando a correspondencia das copias.
   Essa tabela registra a origem historica; o curso atual e derivado de Subject.
7. Somente apos essa verificacao, substituir a restricao antiga de unicidade
   estudante/curso pela de estudante/disciplina e retirar course_id da tabela
   operacional. A FK de curso deve permanecer no historico. Essa substituicao
   precisa constar explicitamente do SQL aprovado; manter a unicidade antiga
   impediria duas disciplinas do mesmo curso para o mesmo estudante.
8. Atualizar Application/Schema.sql, regenerar modelos pelo IHP e adaptar os
   controllers/views que ainda usam Enrollment.courseId antes de liberar escritas.

Nao foi escrito SQL executavel para essa conversao: os dados de mapeamento
nao foram fornecidos. Nao remover nenhuma constraint nesta etapa.

## Validacao futura

Testar a migration em copia isolada com dados legados: contagens e IDs antes
e depois, vinculos de todas as notas, origem dos cursos, rejeicao de dados
invalidos, duplicidade estudante/disciplina, e duas disciplinas distintas do
mesmo curso para um estudante. Conferir tambem rollback em caso de erro.
Os testes CRUD atuais pressupõem matricula por curso e precisarao ser adaptados.

## Resultado da validacao em 19/10/2026

A etapa aditiva original foi aprovada, mas NAO foi aplicada ao banco app.
Backup: /tmp/sga-before-portal-1792451588.dump. Restauracao e migration
validadas em sga_portal_validation_1792451588; constraints rejeitaram nota
11, peso zero e NaN. O banco de validacao foi preservado para inspecao.

O banco app tem as quatro tabelas originais, um registro em cada uma, as FKs
e unicidade previstas no schema, e nao tem schema_migrations. A execucao
isolada no banco de validacao usou MINIMUM_REVISION=1792029677 para nao
reaplicar migrations antigas; somente a revisao 1792451588 foi registrada.

O teste de compilacao dos modelos revelou conflito de exportacao entre
UserRole.Teacher/Student e os construtores dos modelos Teacher/Student.
O schema ativo foi restaurado e os modelos foram regenerados no formato
original. O candidato permanece fora de Application/Migration.

A proposta revisada usa RoleAdmin, RoleTeacher e RoleStudent no PostgreSQL
para evitar a colisao sem alterar o IHP 1.6 nem editar modelos gerados.
Essa mudanca dos valores solicitados exige nova aprovacao. Nao aplicar a
proposta original antes de resolver essa incompatibilidade.
