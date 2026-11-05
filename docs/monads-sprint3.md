# Monads na Sprint 3

## Maybe: média que pode não existir

`Application/Domain/Grade.hs` foi preservado. A assinatura existente é:

```haskell
mediaPonderada :: [(Double, Double)] -> Maybe Double
```

`Nothing` representa lista vazia, nota inválida, peso não positivo, valores
não finitos, soma dos pesos zero ou overflow das somas. `Just` contém uma
média válida. Não há valor artificial como zero para representar ausência.
As views continuam distinguindo ausência de avaliações e avaliações inválidas.

Além de representar ausência, Maybe permite encadear cálculos: `>>=` somente
executa a próxima função quando o resultado anterior é `Just`.

## Either: validação com explicação

`Application/Domain/Validation.hs` oferece `validarNomeEstudante`,
`validarEmail`, `validarNumeroMatricula`, `validarNota`, `validarPeso`,
`validarEstudante` e `validarDadosMatricula`.

Todas retornam `Either Text valor`: `Left` contém o erro e `Right` o valor
validado. O bloco `do` de `validarEstudante` demonstra a instância Monad de
Either: o primeiro erro interrompe o encadeamento.

As regras de nome, e-mail e número de matrícula reutilizam os validadores
**puros** `nonEmpty` e `isEmail` do IHP 1.6. Não há normalização ou mudança dos
valores aceitos. Nota e peso reutilizam `notaValida` e `pesoValido` do domínio.

`validarDadosMatricula` verifica presença de estudante e disciplina e os três
status atuais. Aceita referências genéricas para permanecer independente dos
modelos gerados. Um `Right` não comprova existência no PostgreSQL, unicidade,
autorização ou validade sintática de um UUID textual: essas responsabilidades
continuam no parsing e nas consultas do controller de matrículas. A data
continua automática, sem criação de regras novas para disciplinas.

Nos controllers de estudantes e notas, `validacaoEither`, em
`Application/Helper/Controller.hs`, adapta `Left` para `Failure` do formulário
e `Right` para `Success`. Preservam-se validações por campo, consultas de
unicidade e, para pesos, a validação adicional da precisão `NUMERIC(5,2)`.
`validarPeso 0.001` aceita um peso matematicamente positivo, mas o controller
continua rejeitando-o porque seria armazenado como zero no PostgreSQL.

## IO: efeitos nas bordas

- `Application/Domain/Grade.hs`: cálculos puros.
- `Application/Domain/Validation.hs`: validações puras, sem contexto de banco.
- `Application/Domain/AcademicConfig.hs`: configuração consumida sem IO.
- `Web/Controller/*.hs`: leitura da requisição, consultas, verificações de
  existência/duplicidade, renderização e persistência.
- `Application/Helper/Auth.hs` e `Web/Controller/Sessions.hs`: identidade,
  autorização e operações de sessão existentes.
- `Examples/Monads.hs`: `main :: IO ()` apenas apresenta resultados com `print`.

Não é necessário mover consultas para um serviço novo para separar efeitos.
As assinaturas das funções de domínio não contêm `IO`, `ModelContext` ou
parâmetros implícitos de requisição. Os testes executam esse domínio sem
conexão, sessão ou inicialização do servidor.

## Reader: dependência explícita de configuração

`Application/Domain/AcademicConfig.hs` usa `Reader AcademicConfig` com `ask`,
`asks` e encadeamento `do`. `runReader` fornece o ambiente e produz um resultado
puro. `local`, demonstrado nos testes, altera o ambiente apenas dentro de uma
computação. Reader evita passar os mesmos parâmetros manualmente entre etapas.

A configuração padrão é `AcademicConfig 10 0 20`:

- nota máxima 10;
- peso mínimo **exclusivo** zero, mantendo `peso > 0`;
- limite demonstrativo de 20 registros por página.

`validarAvaliacao` lê limites e retorna um `Either`. Limites alternativos
podem restringir o exemplo, mas não relaxam as regras existentes de nota entre
0 e 10 e peso positivo. Configurações numéricas inválidas retornam `Left`.
`primeiraPagina` demonstra consumo do limite; limites não positivos retornam
lista vazia.

Essas funções são exemplos executáveis: não substituem `ConfigBuilder`, não
aplicam paginação às listagens e não alteram as regras dos controllers.
A dependência explícita `mtl` está declarada em `flake.nix` e no stub `App.cabal`.

## Demonstração no GHCi

No ambiente de desenvolvimento IHP, abra um GHCi sem inicializar o servidor:

```sh
ghci -ignore-dot-ghci -i. Examples/Monads.hs
```

```haskell
:set -XOverloadedStrings
import Control.Monad.Reader
import Application.Domain.Grade
import Application.Domain.Validation
import Application.Domain.AcademicConfig

mediaPonderada [(8,2),(6,3),(10,5)]
-- Just 8.4
mediaPonderada []
-- Nothing
mediaPonderada [(8,0)]
-- Nothing
mediaPonderada [(8,1),(6,-1)]
-- Nothing
mediaPonderada [] >>= (Just . (+ 1))
-- Nothing

validarNota 8
-- Right 8.0
validarNota 11
-- Left "A nota deve estar entre 0 e 10."
validarPeso 0
-- Left "O peso deve ser maior que zero."
validarEstudante "Ana" "ana@example.com" "2026-001"
-- Right ("Ana","ana@example.com","2026-001")
validarEmail "invalido"
-- Left "Informe um e-mail válido."
validarDadosMatricula (Just 1) (Just 2) "active"
-- Right (1,2,"active")
validarDadosMatricula (Nothing :: Maybe Int) (Just 2) "active"
-- Left "Selecione um estudante."

runReader (validarAvaliacao 9 2) configAcademicaPadrao
-- Right (9.0,2.0)
runReader (validarAvaliacao 9 2) (AcademicConfig 8 1 2)
-- Left "A nota excede o máximo configurado."
runReader (primeiraPagina [1..5]) (AcademicConfig 10 0 2)
-- [1,2]

main
-- Executa somente a apresentação IO de Examples.Monads.
```

O GHCi pode exibir caracteres acentuados como escapes numéricos em strings;
isso não altera o conteúdo da mensagem.

## Verificação sem banco

```sh
runghc -ignore-dot-ghci -XBlockArguments -i. Test/Main.hs
runghc -ignore-dot-ghci -i. Examples/Monads.hs
```

`Test/Main.hs` reúne a suíte existente de médias e as novas verificações de
Either, Reader e composição pura. Não chama os runners de CRUD, autenticação,
seed ou migrações, que criam bancos e gravam dados. A separação de efeitos é
verificada pelas assinaturas puras e pela execução sem contexto de banco;
isso não substitui testes de integração dos controllers.

## Functors e avaliação preguiçosa

As demonstrações complementares com `fmap`, listas infinitas e consumo sob
demanda estão em [Functors e Lazy Evaluation](functors-lazy-sprint3.md).

## Continuação explícita no fluxo de matrícula

O pipeline e a integração CPS estão documentados em
[CPS no fluxo de matrícula](cps-matriculas-sprint3.md).
