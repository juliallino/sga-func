# Interface do Portal Acadêmico

Implementação com IHP 1.6, HSX, Bootstrap existente, CSS local e JavaScript
nativo. Sem novas dependências, fontes remotas, imagens ou bibliotecas de ícones.
Não exige migration nem altera os dados acadêmicos.

## Comportamento

- Cabeçalho com identificação SGA, nome e perfil da conta.
- Menu lateral em desktop, recolhível em mobile, com estado ativo e logout POST.
- Navegação por teclado, link para pular ao conteúdo, foco visível, botões
  identificados, menu com aria-expanded e suporte a movimento reduzido.
- Cartões com indicadores reais (COUNT do PostgreSQL) para Admin; contagens
  pessoais para estudante e professor, sem expor totais administrativos.
- Tabelas, formulários, botões, detalhes e mensagens existentes padronizados.
- Nomes de estudante/curso nas matrículas e rótulos legíveis nas avaliações.
- Botões administrativos não são renderizados para outros perfis; os guards
  de servidor continuam obrigatórios.
- Usuários é uma consulta restrita a Admin; não expõe passwordHash e não
  acrescenta criação/edição/exclusão de contas a esta etapa visual.

## Limites acadêmicos preservados

Enrollment ainda referencia Course. Por isso, Minhas disciplinas explica onde
consultar os vínculos atuais, sem atribuir automaticamente disciplinas do curso.
O professor vê somente teacher_subjects autorizados. Estudantes vinculados e
lançamento de avaliações informam sua indisponibilidade enquanto as matrículas
não tiverem disciplina comprovada. Essas páginas não ampliam permissões.
Minhas médias usa as matrículas e avaliações do próprio estudante e a mesma
função pura de média ponderada, com estados para ausência ou invalidade de notas.

## Arquivos desta etapa

- static/app.css: identidade, componentes e regras responsivas.
- static/app.js: interação do menu e ciclo de navegação Turbolinks.
- Application/Helper/View.hs: perfil visual e ícones SVG locais.
- Web/View/Layout.hs: cabeçalho, menu por perfil, shell e layout de login.
- Web/View/Sessions/New.hs: apresentação do login.
- Web/Controller/Static.hs e Web/View/Static/Welcome.hs: dashboards, páginas
  pessoais, médias e disponibilidade das funcionalidades do professor.
- Web/Types.hs, Web/Routes.hs e Web/FrontController.hs: registro das páginas.
- Web/Controller/Users.hs e Web/View/Users/Index.hs: consulta administrativa.
- Web/Controller/Enrollments.hs e Web/Controller/Grades.hs: dados relacionados
  limitados aos registros autorizados para apresentar rótulos legíveis.
- Web/View/Enrollments/Index.hs e Show.hs: nomes, controles e avaliações.
- Web/View/Grades/Index.hs: rótulos legíveis e controles por perfil.
- Web/View/Students/Index.hs e Show.hs: controles por perfil e Meu perfil.
- Web/View/Subjects/Index.hs e Show.hs: controles por perfil e consulta do curso.
- Test/Auth.hs: testes de dashboard, menu, consulta e segurança.
- README.md e este documento: instruções e escopo.

## Verificações

- Compilação GHC/IHP 1.6: 105 módulos.
- 50 testes CRUD/integridade e 20 testes de autenticação/portais em PostgreSQL
  temporário isolado: sem falhas.
- 16 testes de domínio: sem falhas; média ponderada preservada.
- node --check static/app.js e git diff --check.
- Firefox headless: login e dashboard em desktop (1440 px); layout mobile
  (viewport efetivo de 500 px), abertura do menu, tabela com rolagem interna,
  ausência de overflow horizontal na página e formulário sem data editável.

Os valores observados no dashboard local vieram do banco real. A verificação
visual autenticada apenas consultou os dados e não criou registros acadêmicos.

Para reproduzir testes no ambiente IHP carregado:

```bash
python3 Test/run-crud-tests.py
runghc -XBlockArguments Test/Main.hs
node --check static/app.js
```
