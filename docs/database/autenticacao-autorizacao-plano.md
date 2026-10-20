# Autenticacao e autorizacao — proposta para aprovacao

## Analise do estado atual

Nao ha controller de sessoes, login/logout, authMiddleware nem validacao de
permissoes nos controllers academicos. Config.config esta vazio e initContext
so configura o layout. Portanto, as rotas academicas atuais sao publicas.

Existe users com password_hash e role; Student e Teacher possuem user_id
opcional e unico. Serao reutilizados. O SQL usa RoleAdmin/RoleTeacher/RoleStudent;
o gerador IHP 1.6 os expoe como Roleadmin/Roleteacher/Rolestudent e chama o
campo Haskell de role_. Nao editar manualmente os modelos gerados.

Foram consultados os modulos locais IHP.AuthSupport.Authentication,
IHP.AuthSupport.Controller.Sessions e IHP.LoginSupport.Helper.Controller.
hashPassword usa Crypto.PasswordStore.makePassword com strength 17;
verifyPassword verifica esses hashes. O createSessionAction nativo requer
failedLoginAttempts e lockedAt. Esses dois campos estao incluidos na proposta
para reutilizar o fluxo padrao, inclusive bloqueio por tentativas invalidas.

## Mudanca minima proposta

SQL revisavel em autenticacao-autorizacao-proposta.sql, fora da pasta de
migrations automaticas. Criar teacher_subjects com UUID, duas FKs, unicidade
do par e indice por disciplina. Uma associacao autoriza o professor naquela
disciplina; nao e necessario adicionar turmas nem permissao por avaliacao.
Admin concede/revoga o vinculo. Professores nao podem conceder permissoes.

As FKs impedem excluir professor/disciplina com associacoes sem primeiro
revogar os vinculos explicitamente. Adaptar os respectivos controllers para
mensagem amigavel; nenhuma exclusao em cascata.

Adicionar users.failed_login_attempts (INT NOT NULL DEFAULT 0) e locked_at
(TIMESTAMPTZ opcional). Nenhuma senha, role, ID ou conta existente sera
sobrescrita. Hashes existentes devem ser verificados sem exibir seu conteudo;
hashes incompativeis exigem redefinicao de senha, sem converter ou inventar
senhas. Nao criar credenciais fixas nem promover contas automaticamente.

## Autenticacao e administracao de contas

Depois da aprovacao: registrar authMiddleware @User, CurrentUserRecord,
HasNewSessionUrl e SessionsControllerConfig; criar rotas de login e logout
e usar hashPassword/verifyPassword e sessao nativa. Login pode ser publico;
rotas academicas e administracao de contas exigem sessao e permissao.
Logout deve usar metodo de escrita, sem logout por GET. Manter protecao CSRF
do framework para operacoes de escrita e verificar esse comportamento nos testes.

Admin cadastra/edita contas e atribui perfis; formularios comuns nao podem
alterar role_, passwordHash ou user_id por parametros adicionais. Vinculos
Student/User e Teacher/User exigem perfil correspondente e verificacao no
servidor, sem associar por e-mail automaticamente. Nao permitir remover ou
rebaixar o ultimo administrador. A primeira conta administrativa sera criada
por comando local interativo com senha oculta, sem credencial fixa ou senha
em argumentos/logs; nao executar seu provisionamento automaticamente.

Usar segredo de sessao externo ao codigo. A configuracao de producao ainda
tem sessionSecret de exemplo; substituir por segredo real no ambiente de
deploy antes de usa-lo. Nao imprimir o segredo.

## Politica de acesso a implementar

| Perfil | Leitura | Escrita |
| --- | --- | --- |
| Admin | Cadastros e informacoes academicas | Todos os CRUDs, contas e teacher_subjects |
| Teacher | Disciplinas atribuidas e dados academicos dos alunos matriculados nelas, sem acesso a contas/senhas | Criar/editar avaliacoes apenas nas disciplinas atribuidas; sem alterar a matricula de uma avaliacao existente |
| Student | Seu cadastro, suas matriculas, disciplinas/cursos correspondentes e suas avaliacoes/medias | Nenhuma escrita academica |

Teacher nao recebe exclusao de notas nem alteracao de cadastros por padrao.
Consultas devem filtrar por user_id e vinculos autorizados no banco; detalhes,
formularios e escritas devem repetir a checagem por registro. Nao confiar no
UUID vindo da URL, no seletor, nos botoes ocultos ou no perfil enviado no POST.
Negar acesso a perfis sem vinculo Student/Teacher valido, sem ampliar acesso.
Ao editar avaliacao, autorizar o registro atual e impedir troca de enrollment_id.
Reconsultar permissoes em cada requisicao, inclusive apos revogacao do vinculo.

## Dependencia ainda pendente: Enrollment -> Subject

O schema atual ainda usa Enrollment.course_id; subject_id nao existe. A ultima
conferencia do banco encontrou uma matricula antiga com avaliacao e nenhuma
disciplina. A conversao aguarda mapeamento real (ver
matriculas-disciplinas-pendencias.md).

teacher_subjects sozinho nao identifica a disciplina das avaliacoes antigas.
Nao conceder acesso pelo curso, por coincidencia de nomes ou por outro criterio
inferido. Enquanto nao houver subject_id validado, Teacher nao pode consultar
alunos/notas de matriculas por curso nem criar/editar suas avaliacoes. Pode
consultar as disciplinas explicitamente atribuidas. Admin continua gerenciando
as matriculas antigas; Student pode ler apenas as suas, pelo student_id.

## Testes planejados apos aprovacao

Usar PostgreSQL temporario com Admin, dois professores e dois estudantes,
com senhas de teste hasheadas pelo mesmo mecanismo nativo. Nenhuma conta
de teste sera criada no banco real.

1. Login valido/invalido, bloqueio por tentativas, logout e sessao invalida.
2. Visitante nao acessa rotas academicas nem POST/DELETE privados.
3. Admin gerencia os seis CRUDs, contas e associacoes.
4. Student A ve seus dados, notas/medias e estado sem avaliacoes; trocar UUID
   para Student B em GET/POST nao permite ler nem alterar registros.
5. Teacher atribuido pode criar/editar notas da disciplina comprovada; outro
   professor e barrado, inclusive por requisicao direta e manipulacao de campos.
6. Revogar teacher_subjects bloqueia as requisicoes seguintes.
7. Matricula legada sem disciplina nunca autoriza acesso Teacher por curso.
8. FKs/unicidade e exclusoes protegidas; conta de usuario preservada ao excluir
   perfil; role_ e user_id nao podem ser manipulados por usuarios comuns.
9. Senhas persistidas diferem do texto original e verificam com verifyPassword;
   senha/hash nunca aparece nas listagens ou logs.
10. Media ponderada e CRUDs existentes continuam cobertos por regressao.

Nenhuma autenticacao ou migration foi implementada nesta etapa de proposta.
