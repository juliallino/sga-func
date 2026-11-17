# Frequência e requisito mínimo de 75 %

## O que foi adicionado

- **Chamada por aula.** Admin e professores (somente nas disciplinas autorizadas
  em `teacher_subjects`) registram a chamada de cada aula: data, conteúdo
  opcional e presença ou falta de cada matrícula **ativa** da disciplina.
- **Cálculo da frequência.** Para cada matrícula:
  `frequência = presenças ÷ aulas com chamada registrada`.
  Sem chamadas registradas não há frequência (não vira 0 %).
- **Requisito de aprovação.** A frequência mínima é **75 %** (limite incluído:
  3 presenças em 4 aulas atendem ao requisito). O requisito é independente da
  média:
  - matrícula **concluída** abaixo de 75 % → **Reprovado por frequência**,
    qualquer que seja a média;
  - matrícula **em andamento** abaixo de 75 % → **Frequência abaixo de 75 %**
    (alerta, ainda sem reprovação);
  - frequência regular ou sem chamadas → vale a classificação pela média.

## Onde aparece

| Perfil | Tela |
| --- | --- |
| Admin | Menu **Frequência** (`/ClassSessionSubjects`) → disciplina → chamadas |
| Professor | Menu **Chamada e frequência**; também em *Minhas disciplinas* e *Meus estudantes* |
| Estudante | *Minhas disciplinas* e *Minhas notas* (coluna Frequência) e detalhes da matrícula |

O dashboard do professor ganhou a coluna *Frequência abaixo de 75 %* e a lista
de estudantes da disciplina mostra frequência e situação de cada um.

## Banco de dados

Migração aditiva `Application/Migration/1794923479.sql` (também refletida em
`Application/Schema.sql`):

- `class_sessions`: aula de uma disciplina (`subject_id`, `class_date`, `topic`).
- `attendances`: presença (`present`) de uma matrícula em uma aula; uma linha
  por par aula/matrícula (`UNIQUE`).

Sem exclusões em cascata. Excluir uma chamada remove antes as suas presenças.
Matrículas e disciplinas com chamadas não podem ser excluídas, e a disciplina
de uma matrícula com chamadas não pode ser trocada.

## Código

- Regra pura: `Application/Domain/Attendance.hs` (sem banco nem IO) e
  `classifyEnrollment` em `Application/Domain/Academic.hs`.
- Testes: `Test/Domain/AttendanceSpec.hs` (incluído em `Test/Main.hs`).
- Controller: `Web/Controller/ClassSessions.hs`; telas em `Web/View/ClassSessions/`.

## Como testar

```bash
runghc -XBlockArguments Test/Main.hs     # testes de domínio, incluindo frequência
python3 Test/run-crud-tests.py           # integração + verificação da migração
```

Em um banco já existente, aplique a migração com `migrate` (ou pela IDE do IHP).
