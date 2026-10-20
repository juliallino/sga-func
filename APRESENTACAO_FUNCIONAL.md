# Programação funcional no SGA

Revisão do código Haskell/IHP 1.6 e exemplos executados no GHCi.
Os 13 conceitos solicitados estão presentes. Nenhuma função existente foi removida.

## Preparação da apresentação

Execute os comandos a partir da raiz do projeto, com o ambiente IHP/Nix carregado.
Os dados dos exemplos são valores em memória: não criam estudantes, disciplinas,
matrículas ou notas no PostgreSQL.

**Sessão A — domínio independente do IHP e do banco:**

```bash
ghci -ignore-dot-ghci Application/Domain/Grade.hs
```

Use essa sessão nas seções 3 a 13. O módulo importa somente `Prelude`.
O prompt `ghci>` abaixo é ilustrativo e não faz parte do comando a digitar.

**Sessão B — tipos e records da aplicação:**

```bash
ghci -ignore-dot-ghci -ghci-script "$IHP_LIB/applicationGhciConfig"
```

O arquivo `applicationGhciConfig` pertence ao IHP instalado e carrega as extensões,
packages e caminhos de código do projeto. `IHP_LIB` deve estar definido pelo ambiente
de desenvolvimento. O comando explícito evita depender do carregamento automático
da `.ghci` local, que o GHCi pode ignorar se suas permissões forem muito abertas.
Carregar módulos não executa `main` nem inicia consultas ao banco.

Depois, prepare as seções 1 e 2:

```haskell
:load Web/Types.hs Application/Helper/View.hs
import IHP.Prelude
import Web.Types
import Generated.Types
import IHP.ModelSupport
import Application.Helper.View (enrollmentStatusLabel)
```

## Mapa dos conceitos

| Conceito | Implementação principal | Função ou tipo |
| --- | --- | --- |
| Tipos algébricos | `Web/Types.hs`; `build/Generated/Enums.hs` | `StudentsController`, `EnrollmentStatus`; resultado `Maybe Double` |
| Records | `build/Generated/ActualTypes/Student.hs` e `Subject.hs` | `Student`, `Subject`; `newRecord`, `set` |
| Funções puras | `Application/Domain/Grade.hs` | `mediaPonderada`, `notaValida`, `pesoValido` e auxiliares |
| Média ponderada | `Application/Domain/Grade.hs` | `mediaPonderada`, `mediaDaMatricula`, `calcularMediaNotas` |
| Validações funcionais | `Application/Domain/Grade.hs`; `Web/Controller/Grades.hs` | `notaValida`, `pesoValido`, `numeroFinito`, `buildGrade` |
| Closures | `Application/Domain/Grade.hs` | `criarCalculadoraMedia` |
| Currying | `Application/Domain/Grade.hs` | `filtrarNotasAprovadas` |
| List comprehensions | `Application/Domain/Grade.hs` | `mediaPonderada`, cálculos de `somaPonderada` e `pesoTotal` |
| Pattern matching | `Application/Domain/Grade.hs`; `Application/Helper/View.hs` | `mediaPonderada []`, pares `(nota,peso)`, `enrollmentStatusLabel` |
| `map` | `Application/Domain/Grade.hs` | `calcularMediaNotas`, `aplicarBonus` |
| `filter` | `Application/Domain/Grade.hs`; `Web/Controller/Static.hs` | `filtrarNotasAprovadas`, `summarize` |
| `foldl` | `Application/Domain/Grade.hs` | `somarNotas` |
| `concatMap` | `Application/Domain/Grade.hs` | `duplicarInformacoesNotas` |

Os arquivos em `build/Generated/` são gerados pelo IHP a partir de
`Application/Schema.sql`; não devem ser editados manualmente. As funções de
construção/atualização de records vêm do IHP; os tipos `Student` e `Subject`
são os modelos reais do SGA.

## 1. Tipos algébricos

**Arquivos:** `Web/Types.hs`, `Application/Schema.sql`, `build/Generated/Enums.hs`
e `Application/Domain/Grade.hs`.

**Tipos:** `StudentsController`, `EnrollmentStatus` e `Maybe Double`.

`StudentsController` é um tipo soma: cada construtor representa uma ação.
`ShowStudentAction`, por exemplo, carrega um `Id Student`. `EnrollmentStatus`
representa as situações permitidas: `Active`, `Suspended` e `Completed`.
`Maybe Double` representa a existência (`Just`) ou ausência (`Nothing`) de
uma média calculável, sem inventar uma média zero.

Na sessão B:

```ghci
ghci> :t StudentsAction
StudentsAction :: StudentsController
ghci> :t Active
Active :: EnrollmentStatus
ghci> enrollmentStatusLabel Active
"Ativa"
ghci> map inputValue [Active,Suspended,Completed]
["active","suspended","completed"]
```

Os nomes Haskell dos status e os valores PostgreSQL são diferentes de forma
intencional: `Active` é convertido em `"active"` pelo código gerado.

## 2. Records e imutabilidade

**Arquivos:** `build/Generated/ActualTypes/Student.hs`,
`build/Generated/ActualTypes/Subject.hs` e seus módulos gerados de suporte.

**Tipos/funções:** `Student`, `Subject`, `newRecord` e `set`.

Records agrupam campos nomeados, como nome, e-mail e número de matrícula.
`set` produz outro record; não altera o valor original nem grava no banco.
A persistência é uma operação separada, como `createRecord :: ... => ... -> IO ...`.

Na sessão B:

```ghci
ghci> let original = newRecord @Student
ghci> let aluno = original |> set #name "Julia" |> set #email "julia@exemplo.test" |> set #enrollmentNumber "MAT-001"
ghci> (aluno.name, original.name)
("Julia","")
ghci> aluno.enrollmentNumber
"MAT-001"
ghci> let disciplina = newRecord @Subject |> set #name "Programacao Funcional" |> set #code "PF-01" |> set #workload 60
ghci> (disciplina.name, disciplina.workload)
("Programacao Funcional",60)
```

Esses records são apenas demonstrações em memória e não representam cadastros
persistidos ou completos; a referência ao curso não foi preenchida no exemplo.

## 3. Funções puras

**Arquivo:** `Application/Domain/Grade.hs`.

**Funções:** `mediaPonderada`, `notaValida`, `pesoValido`, entre outras.

Os resultados dependem das entradas, sem consultar banco, ler sessão, obter data
ou executar `IO`. Os controllers obtêm os dados autorizados e entregam valores
às funções de domínio. Operações puras sobre listas também preservam os originais.

Na sessão A:

```ghci
ghci> let notas = [5,7,9] :: [Double]
ghci> aplicarBonus 2 notas
[7.0,9.0,10.0]
ghci> notas
[5.0,7.0,9.0]
```

A chamada devolveu uma nova lista; `notas` permaneceu igual.

## 4. Cálculo de média ponderada

**Arquivo:** `Application/Domain/Grade.hs`.

**Funções:** `mediaPonderada`, `calcularMediaNotas` e `mediaDaMatricula`.

Cada par é `(nota, peso)`. A fórmula é `soma(nota * peso) / soma(peso)`.
A função exige notas entre 0 e 10 e pesos positivos, todos finitos. Entrada
vazia, valores inválidos ou somas não finitas resultam em `Nothing`.

Na sessão A:

```ghci
ghci> mediaPonderada [(8,1),(6,3)]
Just 6.5
ghci> mediaDaMatricula [(7.5,1),(9,3)]
Just 8.625
ghci> mediaPonderada []
Nothing
ghci> mediaPonderada [(11,1)]
Nothing
```

No primeiro exemplo: `(8*1 + 6*3) / (1+3) = 6.5`.

**Uso real:** `Web/Controller/Enrollments.hs`, em `calcularMediaEnrollment`, e
`Web/Controller/Static.hs`, em `summarize`, reutilizam `mediaDaMatricula`.
A view somente apresenta o valor ou a mensagem adequada; não recalcula a média.

## 5. Validações funcionais

**Arquivos:** `Application/Domain/Grade.hs` e `Web/Controller/Grades.hs`.

**Funções:** `notaValida`, `pesoValido`, `numeroFinito` e `buildGrade`.

Os predicados puros devolvem `Bool`. O controller converte o número do modelo
para `Double` e usa esses mesmos predicados em `validateField`, com mensagens
para o formulário. O adaptador nativo `isTrue` converte o `Bool` do domínio
em `ValidatorResult`, exigido pelo IHP 1.6; a composição utilizada é
`isTrue . notaValida . realToFrac` (e a equivalente para peso). Regras que dependem da existência de matrícula continuam
separadas, em consultas `IO`; não são chamadas de puras.

Na sessão A:

```ghci
ghci> map notaValida [-1,0,10,11,0/0,1/0]
[False,True,True,False,False,False]
ghci> map pesoValido [-1,0,0.5,0/0,1/0]
[False,False,True,False,False]
```

`0/0` representa `NaN`, e `1/0` representa infinito no tipo `Double`.
Ambos são rejeitados. A proteção do PostgreSQL permanece complementar.

## 6. Closures

**Arquivo:** `Application/Domain/Grade.hs`.

**Função:** `criarCalculadoraMedia`.

A função devolve uma lambda que captura `pesosFixos` do ambiente léxico.
A calculadora pode ser reutilizada sobre diferentes conjuntos de notas.

Na sessão A:

```ghci
ghci> let calcular = criarCalculadoraMedia [(0,1),(0,3)]
ghci> calcular [(8,99),(6,99)]
Just 6.5
ghci> calcular [(8,1)]
Nothing
```

A API existente recebe pares tanto na configuração quanto nas notas.
Na configuração, o primeiro componente de cada par é ignorado; nas entradas,
o segundo componente é substituído pelo peso capturado. Por isso os pesos `99`
não participam da conta. Listas de tamanhos diferentes resultam em `Nothing`.
Essa calculadora já existia como exemplo didático; não substitui os pesos
persistidos das avaliações do portal.

## 7. Currying e aplicação parcial

**Arquivo:** `Application/Domain/Grade.hs`.

**Função:** `filtrarNotasAprovadas`.

A assinatura `Double -> [Double] -> [Double]` equivale a
`Double -> ([Double] -> [Double])`: fornecer o limite retorna uma função que
aguarda a lista. A aplicação parcial é um uso dessa forma curried.

Na sessão A:

```ghci
ghci> :t filtrarNotasAprovadas
filtrarNotasAprovadas :: Double -> [Double] -> [Double]
ghci> :t filtrarNotasAprovadas 7
filtrarNotasAprovadas 7 :: [Double] -> [Double]
ghci> let aprovadas = filtrarNotasAprovadas 7
ghci> aprovadas [5,7,9]
[7.0,9.0]
```

O limite é inclusivo. Essa função filtra números, mas não implementa uma
política completa de aprovação de matrículas nem altera seu status.

## 8. List comprehensions

**Arquivo:** `Application/Domain/Grade.hs`.

**Função:** `mediaPonderada`, nos valores locais `somaPonderada` e `pesoTotal`.

A compreensão percorre os pares e produz os termos da soma ponderada.
Na soma dos pesos, o padrão `(_, peso)` descarta a nota.

Na sessão A, usando a mesma expressão presente na implementação:

```ghci
ghci> [nota * peso | (nota,peso) <- [(8,1),(6,3)] :: [(Double,Double)]]
[8.0,18.0]
```

A implementação aplica `sum` a essa lista e divide pela soma dos pesos.

## 9. Pattern matching

**Arquivos:** `Application/Domain/Grade.hs`, `Application/Helper/View.hs`,
`Web/View/Enrollments/Show.hs` e `Examples/Grade.hs`.

**Funções:** `mediaPonderada`, `enrollmentStatusLabel` e apresentação da média.

`mediaPonderada []` trata a lista vazia por padrão; `(nota,peso)` decompõe um par.
O `case` sobre `Maybe` trata explicitamente sucesso e ausência de média.
`enrollmentStatusLabel` tem uma equação para cada situação de matrícula.

Na sessão A:

```ghci
ghci> case mediaPonderada [(8,1),(6,3)] of {Nothing -> "Sem media"; Just media -> "Media: " ++ show media}
"Media: 6.5"
ghci> case mediaPonderada [] of {Nothing -> "Sem media"; Just media -> "Media: " ++ show media}
"Sem media"
```

A interface diferencia ausência de avaliações e avaliações inválidas pelo
contexto da lista; `Nothing` sozinho não distingue esses dois casos.

## 10. `map`

**Arquivo:** `Application/Domain/Grade.hs`.

**Funções:** `calcularMediaNotas` e `aplicarBonus`.

`calcularMediaNotas` usa `map (uncurry converterNotaPeso)` para converter os
pares numéricos antes de delegar o cálculo. `aplicarBonus` transforma cada nota,
compondo a soma do bônus com um teto de 10.

Na sessão A:

```ghci
ghci> calcularMediaNotas [(8 :: Int,1 :: Int),(6,3)]
Just 6.5
ghci> aplicarBonus 2 [5,9,10]
[7.0,10.0,10.0]
```

O bônus é uma função didática existente, não é aplicado automaticamente no CRUD.
Ela limita o teto, mas não valida todas as entradas ou impede resultados negativos
com bônus negativo. As validações acadêmicas continuam em `notaValida`.

## 11. `filter`

**Arquivos:** `Application/Domain/Grade.hs` e `Web/Controller/Static.hs`.

**Funções:** `filtrarNotasAprovadas` e `summarize`.

`filter` seleciona elementos da lista segundo um predicado, sem mudar os valores.
Além do exemplo abaixo, `summarize` seleciona em memória as avaliações da matrícula
antes de chamar a função pura de média.

Na sessão A:

```ghci
ghci> filtrarNotasAprovadas 7 [5,7,9]
[7.0,9.0]
```

O `filter` de listas é diferente de `filterWhere` do IHP: este monta uma consulta
SQL, que só será executada quando houver uma operação como `fetch`.

## 12. `foldl`

**Arquivo:** `Application/Domain/Grade.hs`.

**Função:** `somarNotas`.

`foldl (+) 0` acumula as notas da esquerda para a direita, começando em zero.
A soma é uma redução da lista; não deve ser confundida com a média ponderada.

Na sessão A:

```ghci
ghci> somarNotas [5,7,9]
21.0
ghci> somarNotas []
0.0
```

## 13. `concatMap`

**Arquivo:** `Application/Domain/Grade.hs`.

**Função:** `duplicarInformacoesNotas`.

Cada nota produz `[nota, nota * 2]`; `concatMap` concatena essas pequenas listas
em uma única lista. É a demonstração didática já existente, preservada na revisão.

Na sessão A:

```ghci
ghci> duplicarInformacoesNotas [3,5]
[3.0,6.0,5.0,10.0]
```

Não se trata de regra de lançamento ou aprovação. A função não cria avaliações,
não grava no banco e seus resultados não são usados automaticamente como notas;
para outras entradas, o valor dobrado pode ultrapassar o limite acadêmico.

## Separação de responsabilidades e resultado da revisão

- **Domínio:** cálculos e predicados puros em `Application/Domain/Grade.hs`,
  sem importar IHP, modelos gerados ou módulos de PostgreSQL.
- **Controllers:** autenticação, consultas autorizadas, validação de referências
  e adaptação dos dados para chamar o domínio. `buildGrade` reutiliza agora
  `notaValida` e `pesoValido`, preservando as mensagens dos formulários.
- **Views:** apresentação, rótulos de status, estados vazios e formatação decimal.
  `averageText` formata uma média já calculada; não implementa outra média.
- **Demonstração:** `Examples/Grade.hs` imprime exemplos; seu `main` faz `IO`,
  enquanto as funções chamadas continuam puras. Não foram adicionadas funções
  artificiais para cumprir a lista de conceitos.
- **Limite atual do modelo:** as matrículas ainda referenciam cursos. Este texto
  não afirma que a migração para disciplinas esteja concluída.

Verificações realizadas: exemplos das duas sessões executados no GHCi; execução
de `Examples/Grade.hs`; suíte de domínio; compilação da aplicação; regressão de
CRUDs e autorização em PostgreSQL temporário. As validações de notas também foram
exercitadas com valores fora do intervalo, peso negativo e valores que se tornam
não finitos na conversão numérica.

Para repetir os executores existentes no ambiente de desenvolvimento:

```bash
runghc -XBlockArguments Test/Main.hs
runghc -i. Examples/Grade.hs
python3 Test/run-crud-tests.py
```

A suíte CRUD utiliza exclusivamente um PostgreSQL temporário. Nenhuma migration,
credencial ou alteração de dados do banco real faz parte desta revisão.

### Resultado confirmado nesta revisão

- 35 comandos GHCi extraídos dos 13 blocos de exemplos: saídas comparadas
  integralmente com as saídas escritas neste arquivo, incluindo exemplos de
  tipos e records.
- 16 exemplos de Test/Main.hs e 1 de Test/Integration.hs: sem falhas.
- 52 exemplos CRUD/integridade e 22 exemplos de autenticação/portais: sem falhas,
  executados em PostgreSQL temporário.
- Examples/Grade.hs executado com as saídas indicadas pelo próprio programa.
- Aplicação compilada: 105 módulos, compatível com IHP 1.6.
- git diff --check: sem problemas de whitespace.

Na revisão final, `validarPrecisaoPeso` no controller acrescentou uma verificação
específica de armazenamento NUMERIC(5,2), preservando os predicados puros e o
arredondamento de entradas já válidas. Ver [REVISAO_FINAL.md](REVISAO_FINAL.md).
