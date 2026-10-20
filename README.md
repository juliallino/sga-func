# 🎓 SGA-Func — Sistema de Gestão Acadêmica Funcional

> **Disciplina:** Programação Funcional — Universidade de Fortaleza (UNIFOR)  
> **Framework Principal:** [IHP (Integrated Haskell Platform)](https://ihp.digitallyinduced.com/)  
> **Linguagem:** Haskell  
> **Banco de Dados:** PostgreSQL (gerenciado via Nix / IHP)

---

## 📌 Sobre o Projeto

O **SGA-Func** é um sistema web de gestão acadêmica desenvolvido em Haskell, utilizando o paradigma de programação funcional e o framework IHP.

O projeto contempla funcionalidades de gestão acadêmica, incluindo:

- 👨‍🎓 Cadastro e gerenciamento de estudantes.
- 📚 Gerenciamento de cursos e disciplinas.
- 📝 Controle de matrículas e notas.
- 📊 Cálculo da média ponderada por matrícula.

Login, logout e controle de acesso por perfis estão implementados. As rotas
acadêmicas exigem autenticação e verificações no servidor. O dashboard usa
contagens reais do PostgreSQL. A migração de matrículas de curso para disciplina,
a gestão de contas além da consulta e a gestão visual de autorizações de
professores ainda estão pendentes; veja a [revisão final](REVISAO_FINAL.md).

---

## 👥 Equipe e Divisão de Papéis

| Integrante | Papel / Responsabilidade Primária |
|:---|:---|
| **JÚLIA LINO ARAÚJO** | Domínio, DevOps e Qualidade (CI/CD e testes) |
| **PEDRO DAVI CAMPOS VIEIRA** | Backend, Frontend e UX (Views HSX, Forms e SSR) |
| **DAVI TAVARES GADELHA** | Dados e Integração (Schemas, Migrations e Queries) |

---

## 🚀 Como Rodar o Projeto Localmente

Este roteiro parte de um computador sem o ambiente do projeto instalado.
Os comandos abaixo são para **Linux/Ubuntu com Bash**, ambiente usado pela equipe.

### 1. Requisitos

- Linux/Ubuntu, navegador e conexão com a internet.
- Permissão de administrador (`sudo`) para instalar as ferramentas.
- Git, curl, Nix e direnv, instalados conforme os passos abaixo.

**Não é necessário instalar Haskell, Cabal, IHP ou PostgreSQL separadamente:**
o ambiente Nix do projeto fornece essas ferramentas.

### 2. Instalar as ferramentas básicas

No terminal:

```bash
sudo apt update
sudo apt install -y git curl direnv
```

Instale o Nix conforme a [documentação oficial](https://nixos.org/download/):

```bash
curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install | sh -s -- --daemon
```

Siga as instruções do instalador. Depois, **feche e abra o terminal** e confira:

```bash
nix --version
git --version
direnv --version
```

### 3. Configurar Nix e direnv

Ative os recursos usados pelo projeto:

```bash
mkdir -p ~/.config/nix
echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf
```

Se essa configuração já existir, não precisa adicioná-la novamente.
Se já houver uma linha `experimental-features`, inclua `nix-command` e `flakes`
nela em vez de criar uma segunda linha.

Para quem usa Bash, habilite o carregamento automático do ambiente:

```bash
echo 'eval "$(direnv hook bash)"' >> ~/.bashrc
source ~/.bashrc
```

Essa configuração do Bash só precisa ser feita uma vez.

### 4. Clonar o projeto

```bash
git clone https://github.com/juliallino/sga-func.git
cd sga-func
```

Se já clonou, basta entrar na pasta do projeto.

### 5. Carregar o ambiente e iniciar

Dentro da pasta do projeto:

```bash
direnv allow
```

Aguarde o download e a configuração das dependências. **Na primeira execução,
essa etapa pode demorar bastante.** Depois execute:

```bash
direnv exec . bash ./start
```

O script `start` chama `devenv up`. Mantenha o terminal aberto enquanto estiver
usando a aplicação e aguarde a inicialização dos serviços e a compilação.

### 6. Abrir no navegador

| Serviço | Endereço |
|:---|:---|
| Aplicação | [http://localhost:8000](http://localhost:8000) |
| IHP Dev Server / Schema Designer / Data Browser | [http://localhost:8001](http://localhost:8001) |

O PostgreSQL faz parte do ambiente local. **O clone não traz os dados nem as
contas do computador dos outros integrantes.** Os endereços só ficam disponíveis
com os respectivos serviços em execução.

**Banco novo:** use o schema atual em `Application/Schema.sql`. Não execute as
migrações antigas indiscriminadamente: o histórico contém operações de remoção
de dados e incompatibilidades descritas na seção de banco deste README.
Não importe o schema sobre um banco que já tenha dados.

### 7. Criar o primeiro usuário para entrar

O projeto exige login, mas `Application/Fixtures.sql` está vazio e ainda não
existe cadastro público de contas. Para criar uma conta local de administrador:

1. Com o projeto rodando, abra **outro terminal** na pasta do projeto e execute:

   ```bash
   direnv exec . ghci
   ```

2. No prompt do Haskell, execute, substituindo o texto por uma senha local:

   ```haskell
   :set -XOverloadedStrings
   import IHP.AuthSupport.Authentication (hashPassword)
   hashPassword "SUBSTITUA_POR_SUA_SENHA_LOCAL"
   ```

3. Copie o hash retornado, **sem as aspas externas**, e saia:

   ```haskell
   :quit
   ```

4. Abra [http://localhost:8001](http://localhost:8001), procure o **Data Browser**
   e crie um registro na tabela `users`:

   | Campo | Valor |
   |:---|:---|
   | `id` | Use o UUID gerado automaticamente |
   | `name` | Seu nome |
   | `email` | O e-mail escolhido para login |
   | `password_hash` | O hash gerado no terminal |
   | `role` | `RoleAdmin` |
   | `failed_login_attempts` | `0` |
   | `locked_at` | Deixe nulo (`NULL`) |

5. Salve e acesse [http://localhost:8000/Login](http://localhost:8000/Login)
   usando o e-mail e a **senha original**, não o hash.

Use uma senha exclusiva para desenvolvimento, pois esse procedimento a digita
no console. Não coloque a senha original no campo `password_hash` nem salve
credenciais no repositório.

### 8. Rodar nas próximas vezes

```bash
cd sga-func
direnv exec . bash ./start
```

Para encerrar, pressione **Ctrl+C** no terminal que está executando o projeto.

### Problemas comuns

| Problema | Como resolver |
|:---|:---|
| `nix: command not found` | Reabra o terminal após instalar o Nix. |
| Ambiente bloqueado pelo direnv | Execute `direnv allow` dentro da pasta. |
| `devenv: command not found` | Aguarde o ambiente carregar e use `direnv exec . bash ./start`. Se houve erro no carregamento, resolva o erro antes de iniciar. |
| `./start: Permission denied` | Use `bash ./start`, como no roteiro. |
| Porta 8000 ou 8001 ocupada | Encerre a outra instância ou programa que está usando a porta. |
| Login não funciona no banco novo | Crie a conta do passo 7; não há credenciais padrão. |

---

## Interface do Portal Acadêmico

O SGA utiliza as views HSX e o Bootstrap existentes, com identidade azul-escuro,
branco e cinza-claro, menu lateral responsivo, ícones SVG locais e logout por POST.
O dashboard de Admin consulta no PostgreSQL os totais de estudantes, professores,
cursos, disciplinas e matrículas. Não há indicadores fictícios.

Estudantes têm menu próprio, perfil, matrículas, notas e médias ponderadas.
Professores visualizam somente disciplinas autorizadas. Os portais explicam a
indisponibilidade de consultas e lançamentos que dependem da conversão das
matrículas antigas de curso para disciplina; nenhum vínculo é presumido pelo curso.
A tela de Usuários oferece consulta exclusiva para Admin, sem senhas ou hashes.

Detalhes, arquivos e validações: [documentação da interface](docs/interface-portal.md).

---

## Professores e disciplinas

O menu principal oferece acesso aos dois novos CRUDs, com cadastro,
listagem, detalhes, edição e exclusão:

| Cadastro | Endereço | Campos |
|:---|:---|:---|
| Professores | http://localhost:8000/Teachers | Nome, e-mail, número de registro e especialização opcional |
| Disciplinas | http://localhost:8000/Subjects | Nome, código, carga horária e curso |

Cadastre primeiro um curso para criar disciplinas. Os formulários mostram
os erros sem descartar o curso selecionado. E-mails e registros de professores,
e códigos de disciplinas, devem ser únicos nos respectivos cadastros. A carga
horária deve ser positiva e o curso deve existir.

Para testar manualmente, crie um registro em cada cadastro, consulte os
seus detalhes e edite-o. Tente enviar nome vazio, e-mail inválido, registro ou
código repetido e carga horária zero: o formulário deve explicar o erro.
Tente excluir um curso com disciplina: a operação deve ser bloqueada.
Excluir uma disciplina preserva seu curso; excluir um professor preserva sua
conta de usuário, quando houver. Autorizações em `teacher_subjects` precisam
ser revogadas antes de excluir professor ou disciplina. Matrículas ainda
referenciam cursos; essa conversão depende de mapeamento real.

Com o ambiente IHP carregado, execute os testes em PostgreSQL temporário:

```bash
python3 Test/run-crud-tests.py
runghc -XBlockArguments Test/Main.hs
```

A suíte CRUD cobre os seis cadastros e usa exclusivamente seu banco isolado.
Nenhuma migration adicional é necessária para esses CRUDs quando a etapa
aditiva `1792451864` já estiver aplicada.

---

## 🧪 Testes Locais e CI/CD

Este repositório possui um fluxo de **Integração Contínua (CI)** configurado por meio do GitHub Actions.

O workflow está localizado em:

.github/workflows/nix-flake-check.yml


### Executar os testes localmente

Para executar as verificações definidas no Nix Flake, utilize:

nix flake check --impure


Esse comando executa as verificações e os testes definidos na configuração do projeto, conforme as condições do ambiente local.

Para executar diretamente os testes de domínio no ambiente de desenvolvimento:

```bash
runghc -XBlockArguments Test/Main.hs
```

Para testar os CRUDs com escrita, use exclusivamente o executor isolado:

```bash
python3 Test/run-crud-tests.py
```

O executor cria um cluster PostgreSQL temporário em `/tmp`, importa o schema atual,
verifica as migrações aditivas em outro banco desse mesmo cluster e executa
integração, CRUDs e autenticação/autorização. Encerra o servidor ao terminar. Não usa a conexão do banco de desenvolvimento
ou produção. Os arquivos temporários são preservados para inspeção.
Esta suíte é executada manualmente; ainda não está conectada ao workflow de CI.

Roteiro dos 13 conceitos, com exemplos GHCi e resultados verificados:
[APRESENTACAO_FUNCIONAL.md](APRESENTACAO_FUNCIONAL.md).

Exemplos para a apresentação:

```bash
runghc -i. Examples/Grade.hs
```

O banco novo criado a partir do schema e um banco atualizado por migrações são
caminhos distintos. A migração `1792029677.sql`, preparada para restaurar as
FKs e a unicidade em bancos legados, não foi aplicada ao banco local, pois
essas constraints já existiam. As revisões aditivas `1792451864` e
`1792459225` estão aplicadas. Não reaplique as migrações antigas sobre esse banco
ou sobre um banco criado a partir do schema atual. O histórico antigo contém operações de remoção
de dados e um default `'Active'` incompatível com o enum declarado.

### Evolução para Portal Acadêmico

A etapa aditiva da migration `1792451864.sql` acrescenta usuários,
professores, disciplinas e validações de notas/pesos. Matrículas ainda
referenciam cursos: a conversão para disciplinas aguarda mapeamento real.

**Banco local criado pelo schema:** a execução validada usa
`MINIMUM_REVISION=1792029677` com o executor `migrate` do IHP 1.6 para
ignorar o histórico antigo incompatível. Não execute `migrate` sem esse
filtro nesse banco, nem importe `Schema.sql` sobre dados existentes.
Em outros bancos, confira primeiro o estado e o histórico aplicado.
Veja o [registro da migração](docs/database/portal-academico-plano.md).

### Integração Contínua com GitHub Actions

O workflow automatiza as verificações configuradas no repositório, ajudando a identificar problemas e garantir a consistência do projeto durante o desenvolvimento.

---

## 📋 Checklist de Entregas — Sprint 0

Etapa dedicada à configuração inicial do ambiente e à estruturação do projeto.

- [x] **Ambiente de Desenvolvimento:** IHP, PostgreSQL e Nix configurados e testados no Linux/Ubuntu.
- [x] **Scaffolding:** Estrutura inicial do projeto gerada com sucesso via `ihp-new`.
- [x] **Repositório Git:** Versionamento inicial configurado e sincronizado com o GitHub.
- [x] **CI/CD:** Workflow de testes via GitHub Actions configurado e verificado.
- [x] **Documentação:** README.md estruturado com instruções de execução e divisão de responsabilidades da equipe.

---

## 🛠️ Tecnologias Utilizadas

| Tecnologia | Finalidade |
|:---|:---|
| **Haskell** | Linguagem de programação funcional |
| **IHP** | Framework web para desenvolvimento com Haskell |
| **PostgreSQL** | Sistema gerenciador de banco de dados relacional |
| **Nix** | Gerenciamento de dependências e ambiente de desenvolvimento |
| **direnv** | Gerenciamento automático de variáveis e ambientes de desenvolvimento |
| **Git e GitHub** | Controle de versão e hospedagem do repositório |
| **GitHub Actions** | Automação de verificações e integração contínua |

---

## 📄 Licença

Este projeto foi desenvolvido para fins acadêmicos na disciplina de **Programação Funcional**, da Universidade de Fortaleza (UNIFOR).

