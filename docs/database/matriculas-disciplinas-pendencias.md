# Matrículas por disciplina: conferência do banco local

Consulta somente de leitura realizada em 19/10/2026.

- Última revisão aplicada: 1792451864 (etapa aditiva).
- Enrollment tem course_id obrigatório; subject_id ainda não existe.
- Há uma matrícula antiga e uma avaliação vinculada a ela.
- O curso é Prog Func, código 3773.
- Nenhuma disciplina está cadastrada.
- Matrícula: 9c701fde-9dc1-4ac3-91f8-1a552ce16e7e.
- Curso original: afdef68f-3ff2-4a59-8454-1ac2a1758bfc.

Não é possível determinar automaticamente a disciplina dessa matrícula ou
avaliação. É necessário informar nome, código e carga horária da disciplina
real e confirmar que a matrícula e a avaliação antigas correspondem a ela.
Não usar o nome do curso como disciplina fictícia nem duplicar a avaliação.
Não alterar datas antigas como parte desta conversão.

## Sequência para continuidade

1. Receber o mapeamento real e preparar SQL específico para revisão/aprovação.
2. Fazer backup e testar a migração numa cópia isolada dos dados atuais.
3. Preservar o curso original em histórico por enrollment_id, com FKs, sem
   modificar o UUID da matrícula ou grade.enrollment_id.
4. Acrescentar subject_id, preencher pelo mapeamento aprovado e validar
   cobertura, existência e correspondência com o curso original.
5. Garantir subject_id obrigatório e UNIQUE(student_id, subject_id).
   A unicidade antiga estudante/curso precisa ser substituída para permitir
   duas disciplinas do mesmo curso. Preservar a FK do curso no histórico.
6. Aplicar somente depois da aprovação do SQL, atualizar Schema.sql e gerar
   os modelos com IHP 1.6. Não reaplicar migrations históricas incompatíveis.
7. Só então adaptar controllers, formulários, seletores de avaliações e
   proteções de exclusão de disciplinas com matrículas.
8. Validar IDs, datas, status, notas/pesos e vínculos antes/depois, bem como
   média, duplicidades, duas disciplinas do mesmo curso e histórico.

## Fluxo após a conversão

Curso → disciplina vinculada ao curso → estudante → matrícula na disciplina
→ avaliações vinculadas à matrícula → média ponderada calculada pela função
pura existente. O seletor deve apresentar disciplina e curso. Os status
active/suspended/completed e a data automática serão mantidos.

## O que já pode funcionar sem migração

A visualização da matrícula agora lista suas avaliações, com nota, peso e
links de visualização/edição. A média ponderada existente foi preservada.
Sem avaliações, a tela informa essa ausência. Nenhum controller foi alterado
para depender de subject_id. O fluxo atual permanece por curso enquanto a
migração estiver pendente.
