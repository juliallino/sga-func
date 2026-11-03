# CPS no fluxo de matrícula — Sprint 3

## Fluxo existente analisado

`Web/Controller/Enrollments.hs` recebe `studentId`, `subjectId` e `status` por
`fill`. O parsing de UUID e enum fica com o IHP. A criação preserva a data
padrão `CURRENT_DATE`; a edição preserva a data armazenada.

`validarEnrollment` só consulta referências se o registro passar pelo parsing.
Consulta estudante e disciplina, verifica duplicidade e anexa os erros aos campos.
`matriculaDuplicada` busca o mesmo par estudante/disciplina e ignora o próprio ID
na edição. O schema reforça essa regra com
`UNIQUE (student_id, subject_id)` e FKs para estudantes e disciplinas.

Criação e atualização exigem Admin e persistem com `createRecord` e
`updateRecord`, respectivamente, somente no ramo válido de `ifValid`.
Desde a reorganização autorizada de 2026-11-02, as matrículas têm vínculo
obrigatório com disciplinas. Nenhuma regra de turma ou pré-requisito foi adicionada.

## O que é CPS

Em estilo direto, uma função retorna um resultado para o chamador decidir o
próximo passo:

```haskell
case validarDadosMatricula aluno disciplina situacao of
    Left erro -> tratarErro erro
    Right dados -> continuar dados
```

Em Continuation Passing Style, o próximo passo é recebido como função:

```haskell
validarObrigatoriosCPS aluno disciplina situacao continuar tratarErros
```

A continuação de sucesso recebe os dados validados; a de falha recebe os
erros. O tipo de resultado `r` é escolhido pelo chamador. Pode ser texto,
`Either`, um número ou uma ação IO. A implementação é específica de CPS com
duas continuações, sem precisar introduzir `Cont` ou `ContT`.

## Pipeline implementado

Em `Application/Domain/EnrollmentCPS.hs`:

```haskell
validarMatriculaCPS
    :: Maybe aluno -> Maybe disciplina -> Text -> VerificacaoMatricula
    -> ((aluno, disciplina, Text) -> r) -> ([Text] -> r) -> r
validarMatriculaCPS aluno disciplina situacao verificacao sucesso falha =
    validarObrigatoriosCPS aluno disciplina situacao
        (\dados -> validarRegrasMatriculaCPS verificacao
            (\() -> sucesso dados)
            (falha . map mensagemErroRegra))
        falha
```

A continuação da primeira etapa contém a segunda etapa: é ela que determina
como o processamento prossegue. A implementação não se limita a dar um nome
CPS a uma sequência de retornos diretos.

1. Os argumentos recebem os dados da matrícula.
2. `validarObrigatoriosCPS` reutiliza `validarDadosMatricula`, já existente,
   para presença das referências e status `active`, `suspended` ou `completed`.
3. A continuação de sucesso dessa etapa chama `validarRegrasMatriculaCPS`.
4. As regras verificam os fatos de existência e duplicidade recebidos.
5. Sem erros, a continuação final recebe os dados; com erros, a continuação de
   falha recebe as mensagens. A falha dos obrigatórios interrompe o pipeline.

`VerificacaoMatricula` é um retrato de fatos fornecidos pelo chamador. No
controller, os fatos vêm das consultas; nos exemplos, são fictícios. A função
pura não comprova a existência de um registro no banco e não valida o formato
de um UUID textual. Os fatos devem corresponder aos mesmos dados validados.

## Integração preservando o controller

A integração usa a etapa `validarRegrasMatriculaCPS` dentro de
`validarEnrollment`, depois das consultas existentes. A continuação de sucesso
produz `pure enrollment`; a de falha produz o registro com erros por campo.
As três regras e mensagens foram extraídas do controller para o módulo puro.
Preserva-se o acúmulo e a ordem dos erros, inclusive quando disciplina inexistente
e duplicidade são informados juntos.

O pipeline completo é demonstrado independentemente no exemplo. O controller
reutiliza sua etapa de regras, mantendo o parsing/defaults e o comportamento
atual de criação/edição do IHP. Não se adicionou uma segunda interpretação dos
parâmetros da requisição nem obrigatoriedade nova na atualização.

A separação é:

| Responsabilidade | Local |
|---|---|
| Presença e status | `Application/Domain/Validation.hs` |
| Encadeamento CPS, regras e mensagens | `Application/Domain/EnrollmentCPS.hs` |
| Parsing, autorização e consultas | `Web/Controller/Enrollments.hs` e helpers existentes |
| Erros nos campos e ações de sucesso | Continuações fornecidas pelo controller |
| Persistência | `createRecord` / `updateRecord` nos ramos existentes de `ifValid` |

O módulo puro não contém consultas nem executa IO. Pode selecionar uma ação
IO fornecida pelo chamador, assim como qualquer função pura pode construir um
valor do tipo `IO a`; os efeitos acontecem quando essa ação é executada na
camada IO. A continuação de sucesso da validação não significa que a gravação
já ocorreu. FKs e unicidade continuam sendo a garantia final do banco,
inclusive se outra requisição modificar dados após as consultas.

## Demonstração no GHCi

No ambiente de desenvolvimento do projeto:

```sh
ghci -ignore-dot-ghci -i. Examples/EnrollmentCPS.hs
```

```haskell
:set -XOverloadedStrings
import Application.Domain.EnrollmentCPS

exemploMatricula False
-- "Sucesso: EST-DEMO-1 em CURSO-DEMO-1"
exemploMatricula True
-- "Erro: Este aluno já está matriculado nesta disciplina."

-- O mesmo pipeline com continuações Right/Left:
validarMatriculaCPS (Just 1) (Just 2) "active" (VerificacaoMatricula True True False) Right Left
-- Right (1,2,"active")

validarMatriculaCPS (Nothing :: Maybe Int) (Just 2) "active" (VerificacaoMatricula True True False) Right Left
-- Left ["Selecione um estudante."]

validarMatriculaCPS (Just 1) (Just 2) "active" (VerificacaoMatricula True True True) Right Left
-- Left ["Este aluno já está matriculado nesta disciplina."]

-- O chamador pode escolher outro resultado, sem alterar o pipeline:
validarMatriculaCPS (Just 1) (Just 2) "active" (VerificacaoMatricula True True False) (const True) (const False)
-- True

main
-- Apresenta sucesso, duplicidade e ausência de estudante, sem acessar o banco.
```

O GHCi pode representar acentos com escapes ao usar `print`. O executável usa
`Data.Text.IO.putStrLn` para apresentar mensagens legíveis.

Para a apresentação, mostre primeiro a assinatura com as duas continuações,
depois a lambda que encaminha os dados à próxima etapa. Execute sucesso,
duplicidade e ausência de estudante. Finalize mostrando a etapa integrada ao
controller e onde a persistência continua separada.

## Testes e execução

```sh
runghc -ignore-dot-ghci -XBlockArguments -i. Test/Main.hs
runghc -ignore-dot-ghci -i. Examples/EnrollmentCPS.hs
```

`Test/Domain/EnrollmentCPSSpec.hs` cobre dados válidos, obrigatórios inválidos,
status existentes, referências inexistentes, duplicidade, erros acumulados,
interrupção de etapas e resultado escolhido pelo chamador. Testes com `error`
comprovam que continuações não selecionadas não são avaliadas. Um teste com
`IORef`, sem PostgreSQL, registra que a ação da continuação selecionada é
executada uma única vez por chamada.

As suítes que criam bancos, persistem registros ou aplicam migrações não fazem
parte dessa execução sem banco. A checagem de tipos da aplicação verifica a
integração; não substitui um teste HTTP/PostgreSQL do controller.
