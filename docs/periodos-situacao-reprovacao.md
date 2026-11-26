# Períodos letivos, matrícula inativa e reprovação por nota

## 1. Reprovação por nota (média mínima 5,0)

- O critério de aprovação passou a ser **média ponderada mínima 5,0**
  (`approvalPolicy = Just (ApprovalPolicy 5 True)` em
  `Application/Domain/Academic.hs`).
- A decisão só acontece quando a matrícula está **Concluída**. Antes disso a
  situação é **Em andamento**.
- Matrícula concluída com média abaixo de 5,0 → **Reprovado por nota**.
  Com 5,0 ou mais → **Aprovado**, desde que a frequência não esteja abaixo de 75 %
  (a frequência continua tendo prioridade: abaixo de 75 % → **Reprovado por frequência**).
- Os painéis do aluno e do professor mostram o critério e as contagens de aprovados
  e reprovados por nota.

## 2. Situação "Inativa" (desativar matrícula)

- Nova situação de matrícula: **Inativa** (`inactive`).
- Matrícula com notas ou chamadas continua **sem poder ser excluída**; a mensagem
  agora orienta a usar **Desativar**.
- Na lista de matrículas, o Admin tem o botão **Desativar**, que muda a situação
  para Inativa sem apagar notas nem chamadas. É reversível: basta editar a
  situação de volta.
- Matrícula inativa **some para o estudante** (listas, portal, notas, médias e
  acesso direto pelo endereço retornam "não encontrado"). Admin e professores
  continuam vendo.
- Matrículas inativas não entram no desempenho da turma nem nos rankings.

## 3. Períodos letivos (2026.1, 2026.2)

- Menu **Períodos** (Admin): cadastro com nome no formato `ano.semestre`
  (`2026.1` ou `2026.2`), início e fim das aulas.
  - O nome é único, o fim vem depois do início, o início fica no ano do período
    e os períodos não podem se sobrepor.
  - Período com matrículas não pode ser excluído.
- Cada matrícula tem um **período letivo**. Na nova matrícula, o sistema sugere o
  período em andamento. Matrículas antigas ficam "Sem período" até o Admin editar.
- O estudante pode **refazer** uma disciplina em outro período: a regra de
  unicidade passou de (estudante, disciplina) para (estudante, disciplina, período).
  Nas médias por curso e nos rankings vale a matrícula do período mais recente.
- O estudante vê a coluna **Período** e um **filtro por período** em
  *Minhas disciplinas*. O professor vê o período na lista de estudantes da
  disciplina, e a matrícula mostra o período nos detalhes.

## Banco de dados

Migrações aditivas, aplicadas com `migrate`:

| Migração | O que faz |
| --- | --- |
| `1795726632.sql` | Acrescenta `inactive` ao tipo `enrollment_status`. |
| `1795726633.sql` | Cria `academic_periods`, acrescenta `enrollments.academic_period_id` (opcional) e troca a unicidade por `(student_id, subject_id, academic_period_id) NULLS NOT DISTINCT`. |

Nenhum dado existente é apagado ou alterado. `NULLS NOT DISTINCT` exige
PostgreSQL 15 ou mais recente.

## Código e testes

- Regras puras: `Application/Domain/Period.hs` (formato, datas, sobreposição,
  período em andamento) e o critério em `Application/Domain/Academic.hs`.
- Testes: `Test/Domain/PeriodSpec.hs`, `Test/Domain/AcademicSpec.hs` e
  `Test/Domain/EnrollmentCPSSpec.hs` (situação `inactive`).
- Telas: `Web/Controller/AcademicPeriods.hs`, `Web/View/AcademicPeriods/`.
