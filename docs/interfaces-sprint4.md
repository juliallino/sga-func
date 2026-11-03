# Interfaces da Sprint 4

As páginas usam HSX e SSR do IHP 1.6, com Bootstrap e os componentes do projeto.
A identidade visual compartilhada usa azul-escuro, branco e cinza-claro. O menu
responsivo, os cards, tabelas, formulários, feedback de validação, mensagens de
sessão e estados vazios preservam os fluxos existentes.

## Páginas e alcance

| Portal | Páginas |
| --- | --- |
| Administração | Dashboard; estudantes, professores, cursos, disciplinas, matrículas e avaliações com listagem, criação, edição e detalhes; vínculos docentes; consulta de contas |
| Professor | Dashboard, minhas disciplinas, meus estudantes, lançamento de notas, consulta de avaliações e perfil |
| Estudante | Dashboard, minhas disciplinas, minhas notas, minhas médias, matrículas e perfil |

A consulta de contas é a funcionalidade existente. Criação, edição e exclusão de
contas continuam sem implementação; não são anunciadas pela interface.

**Limitação funcional preservada:** o modelo atual relaciona matrículas a cursos,
sem `subject_id`. As telas docentes de estudantes, avaliações e lançamento de
notas apresentam as disciplinas explicitamente autorizadas e explicam a pendência.
Não permitem consultar estudantes nem lançar notas a partir de uma associação
inferida pelo curso. No portal do estudante, os cursos e resultados existentes
são apresentados como cursos e resultados por matrícula, sem inventar disciplinas.
A conclusão funcional desses fluxos depende de uma etapa posterior de dados.
Nenhum schema, migration ou dado do banco local foi alterado nesta etapa.

## Arquivos trabalhados nesta etapa

- `Application/Helper/View.hs`: componentes de estado vazio e ações de formulário.
- `Web/View/Layout.hs`: navegação docente e seleção do item em formulários/detalhes.
- `Web/View/Static/Welcome.hs`: atalhos administrativos e cabeçalhos de tabelas.
- `Web/View/Students/{Index,New,Edit,Show}.hs`.
- `Web/View/Courses/{Index,New,Edit,Show}.hs`.
- `Web/View/Teachers/{Index,Form,Show}.hs`.
- `Web/View/Subjects/{Index,Form,Show}.hs`.
- `Web/View/Enrollments/{Index,Form,Show}.hs`.
- `Web/View/Grades/{Index,Form,Show}.hs`.
- `Web/View/Users/Index.hs`.
- `Web/View/TeacherSubjects/Index.hs`.
- `Web/View/TeacherPortal/{Dashboard,Subjects}.hs`.
- `Web/View/StudentPortal/{Academic,Dashboard}.hs`.
- `Web/Controller/Static.hs`, `Web/Controller/Grades.hs`, `Web/Types.hs` e
  `Web/Routes.hs`: telas docentes distintas e contexto legível das avaliações.
- `static/app.css`: paleta unificada, estados vazios e ajustes responsivos.
- `Test/Auth.hs`: cobertura HTTP das páginas, isolamento por perfil e exportação
  opcional de amostras fictícias (`SGA_INTERFACE_SNAPSHOTS`, diretório existente).

## Validação

A suíte HTTP verifica listagens, criação/edição, detalhes, layout SSR, mensagens
de validação e sucesso, acesso por UUID, bloqueio de escrita e isolamento dos
perfis. O executor cria exclusivamente um cluster temporário em `/tmp`:

```bash
python3 Test/run-crud-tests.py --skip-migrations
```

O parâmetro evita executar migrações mesmo no banco temporário. Não use o banco
local como destino dos testes. A compilação da aplicação é verificada com GHC
`-fno-code`, usando as extensões do ambiente IHP.

Resultado verificado: compilação dos 113 módulos da aplicação; 104 exemplos
aprovados (integração, CRUD, autenticação/SSR e vínculos docentes), sem falhas.
A inspeção no Firefox headless usou amostras SSR fictícias do dashboard Admin,
dashboard do estudante, estudantes do professor e formulário de estudante, em
1440 px e 500 px de largura efetiva. Não houve transbordamento horizontal da
página; tabelas usam rolagem interna. O menu abriu por clique e fechou por Escape.
As outras páginas foram verificadas pelos testes HTTP; a inspeção visual foi por
amostragem. Não foram executadas migrações.
