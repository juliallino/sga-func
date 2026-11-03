# Functors e Lazy Evaluation no SGA

## Functor e fmap

Um Functor permite transformar valores dentro de um contexto preservando a
estrutura desse contexto. Sua operação é:

```haskell
fmap :: Functor f => (a -> b) -> f a -> f b
```

No SGA, `Application/Domain/AcademicDisplay.hs` define
`notasParaExibicao :: Functor f => f Double -> f Text`. A mesma função pode
receber uma lista de notas, uma média opcional ou uma nota validada:

- Na lista, transforma cada elemento, preservando quantidade e ordem.
- Em `Maybe`, transforma `Just` e mantém `Nothing`.
- Em `Either Text`, transforma `Right` e mantém a mensagem de `Left`.

`nomesParaExibicao` usa `fmap` para retirar espaços nas extremidades e converter
nomes para maiúsculas apenas para apresentação. Não normaliza cadastros nem
substitui as validações existentes. A exibição de notas usa `show`, sem impor
uma nova regra de arredondamento.

`Application/Domain/Grade.hs` já possuía `aplicarBonus`. A função foi reutilizada,
substituindo apenas `map` por `fmap`, equivalentes para listas. Mantém assinatura,
resultado e teto de 10. O bônus é uma demonstração pura: não foi conectado a
nenhum controller ou operação de persistência. Use notas válidas e bônus
positivos para essa demonstração; a função não substitui os validadores de
nota/peso nem introduz novas regras para entradas inválidas.

Os testes demonstram também as leis de identidade (`fmap id = id`) e composição
(`fmap (f . g) = fmap f . fmap g`) em exemplos de listas, Maybe e Either.

## Avaliação preguiçosa

Haskell permite calcular expressões conforme seus resultados são exigidos.
Uma lista infinita pode ser descrita sem ser materializada por inteiro:
`take 5 [1..]` exige somente seus cinco primeiros elementos.

Em `Application/Domain/LazyExamples.hs`:

- `numerosFicticios` é a sequência infinita `[1..]`, usando `Integer` para não
  sofrer overflow de um inteiro de tamanho fixo.
- `matriculasFicticias` aplica `map` para produzir identificadores `DEMO-1`,
  `DEMO-2`, etc., conforme o consumidor solicita elementos.
- `numerosParesFicticios` aplica `filter even` sob demanda. A seleção de pares
  é apenas um exemplo, sem significado de aprovação ou autorização acadêmica.

`take` limita o resultado consumido. Para encontrar cinco resultados, `filter`
pode precisar examinar mais de cinco entradas. Se nenhum elemento satisfizer
um predicado em uma sequência infinita, a busca pode não terminar. Operações
como `length` ou imprimir a sequência inteira também não terminam. Sempre
consuma um prefixo finito nas demonstrações.

Os testes usam caudas com `error` para comprovar que `take`, `map` e `filter`
não exigem partes desnecessárias da lista. Essas expressões deliberadamente
inválidas ficam apenas nos testes. Avaliação preguiçosa não equivale à paginação
SQL: nenhum desses geradores foi ligado a consultas ou usado para gravar
matrículas. Os identificadores são fictícios, sem garantia de unicidade real.

## Exemplos executáveis no GHCi

No ambiente Haskell/IHP do projeto:

```sh
ghci -ignore-dot-ghci -i. Examples/FunctorsLazy.hs
```

```haskell
:set -XOverloadedStrings
import Data.Text (Text)
import Application.Domain.Grade
import Application.Domain.Validation
import Application.Domain.AcademicDisplay
import Application.Domain.LazyExamples

let notas = [6.0, 7.5, 9.0]
aplicarBonus 0.5 notas
-- [6.5,8.0,9.5]
notas
-- [6.0,7.5,9.0]
aplicarBonus 0.5 [9.8,10]
-- [10.0,10.0]

nomesParaExibicao [" Ana Silva ", "Bruno Costa"]
-- ["ANA SILVA","BRUNO COSTA"]
notasParaExibicao notas
-- ["Nota: 6.0","Nota: 7.5","Nota: 9.0"]
notasParaExibicao (mediaPonderada [(8,2),(6,3),(10,5)])
-- Just "Nota: 8.4"
notasParaExibicao (Nothing :: Maybe Double)
-- Nothing
notasParaExibicao (validarNota 8)
-- Right "Nota: 8.0"
notasParaExibicao (Left "Sem avaliação" :: Either Text Double)
-- Left "Sem avaliação"

-- fmap também pode transformar numericamente, sem formatar:
fmap (+ 0.5) (Just 8.0)
-- Just 8.5
fmap (+ 0.5) (validarNota 8)
-- Right 8.5

-- fmap não revalida o resultado: use aplicarBonus para o teto da lista.
take 5 [1..]
-- [1,2,3,4,5]
take 5 numerosFicticios
-- [1,2,3,4,5]
take 3 matriculasFicticias
-- ["DEMO-1","DEMO-2","DEMO-3"]
take 5 numerosParesFicticios
-- [2,4,6,8,10]
take 3 (aplicarBonus 0.5 (repeat 6))
-- [6.5,6.5,6.5]

main
-- Apresenta todos os exemplos, com consumo finito das sequências.
```

## Executar sem acessar o banco

```sh
runghc -ignore-dot-ghci -XBlockArguments -i. Test/Main.hs
runghc -ignore-dot-ghci -i. Examples/FunctorsLazy.hs
```

`Test/Domain/FunctorsLazySpec.hs` integra a suíte de domínio e cobre os três
contextos, bônus, preservação dos valores originais, leis de Functor em exemplos
e consumo sob demanda. Os testes de CRUD, autenticação, seed e migrações são
separados e não são necessários para executar estas demonstrações.

Veja também [Monads na Sprint 3](monads-sprint3.md).
