# Demonstração acadêmica reproduzível — Development

O procedimento usa um banco **novo e separado**, chamado `sga_demo` (ou
`sga_demo_...`), em PostgreSQL local por socket Unix. O banco `app` e conexões
TCP são recusados, inclusive pelo seed Haskell quando chamado diretamente.
Não transporte dumps, contas, chaves de sessão ou inventários de outro computador.
O seed não envia mensagens para os e-mails dos estudantes.

## 1. Ambiente e serviços

Requisitos: Linux, Git, Python 3, Nix com `nix-command flakes` e direnv.
Haskell, IHP 1.6, compilador e PostgreSQL são fornecidos pelo `flake.nix` e
`flake.lock`. Instale Nix usando o instalador oficial e habilite direnv no shell.
Não é necessário instalar GHC/PostgreSQL por fora do ambiente Nix.

```sh
git clone --branch sprint-3 https://github.com/juliallino/sga-func.git
cd sga-func
direnv allow
direnv exec . bash ./start
```

Mantenha esse primeiro terminal aberto para iniciar os serviços, incluindo
PostgreSQL. Na primeira execução, downloads e compilação podem demorar. O banco
padrão vazio `app` não será usado para a carga acadêmica. Não precisa cadastrar
contas nele. A aplicação fica em `http://localhost:8000` e o IDE IHP em
`http://localhost:8001`.

## 2. Criar o banco da demonstração

Em outro terminal, na raiz do projeto, com os serviços iniciados:

```sh
export IHP_ENV=Development
export DEMO_DATABASE_URL="postgresql:///sga_demo?host=$(realpath .devenv/run/postgres)"
direnv exec . python3 scripts/seed-demo.py \
  --database-url "$DEMO_DATABASE_URL" --confirm development-demo \
  --init-db --schema-only
```

`--init-db` cria um banco inexistente e importa, em uma transação, o
`IHPSchema.sql` do IHP e `Application/Schema.sql`. Se o banco já existir,
a inicialização é recusada: nenhum schema é importado sobre dados existentes.
`--schema-only` não cria contas e não solicita senhas.

Este é o caminho para **instalação nova**. Não execute as migrações históricas
sobre esse schema: ele já contém o modelo por disciplina. Bancos legados exigem
outro procedimento, inventário e aprovação próprios. A revisão por disciplina
recusa matrículas legadas; o seed não exclui dados para contornar essa proteção.
Não altere migrações antigas nem execute reset de banco.

## 3. Credenciais locais e carga

Escolha três senhas locais exclusivas, com pelo menos 12 caracteres: uma para
Admin, uma para os cinco professores fictícios e uma para os dez estudantes.
Não há senha padrão. Não salve senhas em arquivos versionados nem em argumentos
da linha de comando.

Em terminal interativo, execute:

```sh
direnv exec . python3 scripts/seed-demo.py \
  --database-url "$DEMO_DATABASE_URL" --confirm development-demo
```

O programa solicita as três senhas com entrada oculta. Para automação local,
configure `SGA_DEMO_ADMIN_PASSWORD`, `SGA_DEMO_TEACHER_PASSWORD` e
`SGA_DEMO_STUDENT_PASSWORD` no ambiente usando um gerenciador de segredos ou
entrada oculta; não inclua valores em scripts versionados. Ausência de
credenciais em execução não interativa causa recusa antes de criar dados.
O `.env.example` contém somente configuração não secreta. `.env` permanece
ignorado; não publique o arquivo se optar por usá-lo localmente.

Production é recusado pelo wrapper e pelo Haskell. O Haskell verifica também
o nome real do banco e se a conexão usa socket local. Não há opções que
redefinam senhas, excluam registros ou ignorem conflitos.

## 4. Base criada e chaves estáveis

| Registro | Quantidade | Identificação |
| --- | --- | --- |
| Curso | 1 | `DEMO-CC`, Ciência da Computação; carga representativa de 300 h |
| Disciplinas | 5 | `DEMO-ALG`, `DEMO-BD`, `DEMO-ES`, `DEMO-REDES`, `DEMO-PF`; 60 h cada |
| Professores e contas Teacher | 5 | `DEMO-DOC-001` a `DEMO-DOC-005` |
| Vínculos docentes | 5 | Um professor por disciplina |
| Estudantes e contas Student | 10 | `DEMO-V2-001` a `DEMO-V2-010` |
| Conta Admin | 1 | `admin.demo@example.test` |
| Matrículas | 50 | Cinco por estudante, dez por disciplina |
| Avaliações iniciais | 120 | Três por matrícula dos primeiros oito estudantes |

Os UUIDs são gerados pelo PostgreSQL. Relacionamentos são resolvidos por códigos
de disciplinas, registros docentes e matrículas estudantis. Não dependem de IDs
do computador de origem.

Os nomes e e-mails estão em
[`reorganizacao-demo-novos-estudantes.csv`](database/reorganizacao-demo-novos-estudantes.csv):
Pedro Lino, Ana Beatriz, Lucas Oliveira, Mariana Costa, Gabriel Almeida, Sofia
Martins, Rafael Ferreira, Julia Santos, Felipe Rocha e Camila Ribeiro. São as
identidades fictícias definidas para a demonstração; nenhum e-mail é enviado.

[`reorganizacao-demo-50-matriculas.csv`](database/reorganizacao-demo-50-matriculas.csv)
usa códigos de disciplinas e registros docentes.
[`reorganizacao-demo-avaliacoes-planejadas.csv`](database/reorganizacao-demo-avaliacoes-planejadas.csv)
contém 150 avaliações planejadas: 120 `initial` e 30 `manual`.
As 30 `manual`, dos dois últimos estudantes, não são inseridas pelo seed.
Ausência de avaliações permanece sem média, sem substituir ausência por zero.

## 5. Acessar os três perfis

Depois da preparação, encerre o primeiro `start` com Ctrl+C e reinicie a
aplicação apontando para o banco da demonstração. No terminal em que definiu
`DEMO_DATABASE_URL`:

```sh
DATABASE_URL="$DEMO_DATABASE_URL" IHP_ENV=Development direnv exec . bash ./start
```

Se existir `.env`, confira se ele não sobrescreve `DATABASE_URL` com outro banco.
Também é possível configurar localmente `.env` a partir de `.env.example`, com
seu próprio socket, e iniciar normalmente. Não copie configuração de outra máquina.

Abra `http://localhost:8000/Login` e use a senha que você forneceu para o perfil:

| Perfil | Login |
| --- | --- |
| Admin | `admin.demo@example.test` |
| Teacher — Algoritmos | `docente.algoritmos@example.test` |
| Teacher — Banco de Dados | `docente.bancodedados@example.test` |
| Teacher — Engenharia de Software | `docente.engenharia@example.test` |
| Teacher — Redes de Computadores | `docente.redes@example.test` |
| Teacher — Programação Funcional | `docente.funcional@example.test` |
| Student | E-mail da linha correspondente no CSV de estudantes |

Admin gerencia os cadastros; Teacher acessa apenas sua disciplina autorizada;
Student acessa apenas os próprios registros. A atribuição é explícita, sem
inferir permissão pelo curso ou por coincidência de e-mail.

## 6. Repetição e conflitos

Repita a carga sem `--init-db`. Registros compatíveis são reutilizados, sem
alterar UUIDs, senhas, notas editadas ou outros campos existentes. Alterar as
senhas na configuração não redefine contas já criadas. Guarde as credenciais
originais em armazenamento local seguro.

Conflitos de identidade, e-mail, curso ou disciplina abortam a transação inteira.
Contas existentes sem o perfil acadêmico correspondente não são associadas
silenciosamente. O procedimento não transforma o banco atual em uma cópia da
demonstração nem realiza limpeza. Nunca use o banco principal como teste.

## 7. Testes

No ambiente IHP/Nix:

```sh
direnv exec . runghc -ignore-dot-ghci -XBlockArguments -i. Test/Main.hs
direnv exec . python3 Test/run-crud-tests.py
direnv exec . python3 Test/run-seed-tests.py
```

Os executores PostgreSQL criam seus próprios clusters em `/tmp`, sem listener
TCP, importam o schema somente nesses bancos novos e encerram os processos ao
terminar. A suíte CRUD verifica migrações somente em banco isolado; `--skip-migrations`
permite omitir essa etapa. A suíte de seed nunca depende de inventários privados,
usa segredos aleatórios em memória e verifica os três perfis, hashes, vínculos,
idempotência, preservação de notas/senhas, rollback de conflitos e recusa de
Production, do banco `app` e de sobrescrita do schema.

Os artefatos temporários de testes são privados e não devem ser publicados.
Não execute o seed Haskell diretamente: use o wrapper, que resolve as ferramentas,
valida a conexão e evita imprimir consultas ou credenciais em caso de falha.
