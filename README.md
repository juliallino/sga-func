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
contagens reais do PostgreSQL. Matrículas relacionam estudantes a disciplinas;
Admin gerencia os vínculos docentes e professores lançam e editam notas somente
nas disciplinas autorizadas. Veja o [guia de demonstração reproduzível](docs/dados-demonstracao.md).

---

## 👥 Equipe e Divisão de Papéis

| Integrante | Papel / Responsabilidade Primária |
|:---|:---|
| **JÚLIA LINO ARAÚJO** | Domínio, DevOps e Qualidade (CI/CD e testes) |
| **PEDRO DAVI CAMPOS VIEIRA** | Backend, Frontend e UX (Views HSX, Forms e SSR) |
| **DAVI TAVARES GADELHA** | Dados e Integração (Schemas, Migrations e Queries) |

---

## 🚀 Instalação local e demonstração reproduzível

Use Linux, Git, Python 3, Nix com `nix-command flakes` e direnv. O Nix fornece
Haskell, IHP 1.6 e PostgreSQL; não instale essas versões separadamente.

```bash
sudo apt update
sudo apt install -y git curl direnv python3
```

Instale Nix pelo [procedimento oficial](https://nixos.org/download/), reabra o
terminal, habilite `experimental-features = nix-command flakes` na configuração
do Nix e `eval "$(direnv hook bash)"` na configuração do Bash. Não duplique linhas
já existentes. Depois:

```bash
git clone --branch sprint-3 https://github.com/juliallino/sga-func.git
cd sga-func
direnv allow
direnv exec . bash ./start
```

O primeiro carregamento pode demorar. Mantenha os serviços abertos; aplicação
em http://localhost:8000 e IDE IHP em http://localhost:8001.

O clone não contém contas nem dados de outro computador. Para uma demonstração
nova e separada, siga [o guia completo](docs/dados-demonstracao.md):

1. Inicie os serviços para disponibilizar o socket PostgreSQL local.
2. Crie um banco dedicado `sga_demo` usando `scripts/seed-demo.py --init-db --schema-only`.
   O wrapper aplica `IHPSchema.sql` e `Application/Schema.sql` somente em banco novo.
3. Execute o seed pelo wrapper com `IHP_ENV=Development` e confirmação
   `development-demo`; forneça senhas locais por entrada oculta ou ambiente.
4. Reinicie a aplicação com `DATABASE_URL` apontando para esse banco.
5. Acesse os perfis Admin, Teacher e Student com os logins descritos no guia
   e as senhas que você definiu localmente.

Não há senha padrão ou credenciais em arquivos versionados. `.env.example`
contém apenas configuração de exemplo; `.env` permanece privado. Não publique
chaves de sessão, dumps, backups, logs ou inventários da sua instalação.

O seed cria ou valida 1 curso, 5 disciplinas, 5 professores com contas, 5 vínculos,
10 estudantes com os nomes/e-mails publicados, 50 matrículas e 120 avaliações.
Relacionamentos usam chaves acadêmicas, sem depender de UUIDs de outra máquina.
Trinta avaliações ficam reservadas para lançamento manual. Repetições preservam
registros e senhas existentes; conflitos causam rollback. O banco `app`, conexões
TCP e Production são recusados para essa carga.

**Banco novo e banco legado são caminhos distintos.** Não execute o histórico
inteiro de migrations sobre o schema atual, nem importe schema sobre banco com
dados. Migrações legadas exigem inventário e procedimento próprios. O seed não
exclui registros para contornar as proteções de migração.

Para encerrar os serviços, use Ctrl+C. Se houver problema com Nix/direnv, confira
as versões instaladas, `direnv allow` e o carregamento do ambiente. O projeto
aceita caminhos com espaços/acentos; os scripts de banco usam o socket local
resolvido, sem caminhos específicos de um integrante.

---

## Interface do Portal Acadêmico

O SGA utiliza as views HSX e o Bootstrap existentes, com identidade roxa,
branco e fundos lilás, menu lateral responsivo, ícones SVG locais e logout por POST.
O dashboard de Admin consulta no PostgreSQL os totais de estudantes, professores,
cursos, disciplinas e matrículas. Não há indicadores fictícios.

Estudantes têm menu próprio, perfil, matrículas, notas e médias ponderadas.
Professores visualizam somente disciplinas autorizadas, seus estudantes e suas
avaliações. A autorização é conferida nos controllers e nas consultas; nenhum
vínculo é presumido pelo curso. Rankings estão em `/Rankings`, com isolamento
por perfil e médias ausentes excluídas.
A tela de Usuários oferece consulta exclusiva para Admin, sem senhas ou hashes.
Admin também gerencia vínculos professor–disciplina em `/TeacherSubjects`,
pelo menu **Vínculos docentes**. Conceder ou revogar uma disciplina controla o acesso docente às suas matrículas
e notas. Inventários e relatórios da base particular não são requisitos para executar
o projeto ou seus testes.

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
ser revogadas antes de excluir professor ou disciplina. Matrículas referenciam disciplinas. A exclusão de uma disciplina com matrículas
é bloqueada para preservar o histórico.

Com o ambiente IHP carregado, execute os testes em PostgreSQL temporário:

```bash
python3 Test/run-crud-tests.py
runghc -XBlockArguments Test/Main.hs
```

A suíte CRUD cobre os seis cadastros e usa exclusivamente seu banco isolado.
Em banco novo, o schema atual contém todas as estruturas necessárias.
Bancos antigos por curso exigem tratamento específico antes da conversão.

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

### Banco novo, migrações e testes de demonstração

O schema atual relaciona matrículas a disciplinas. O histórico de migrações é
preservado para bancos legados; não deve ser reaplicado sobre um banco criado
pelo schema atual. A revisão `1793548800` recusa matrículas legadas não tratadas.
Não use filtros históricos de revisão de outra instalação como receita universal.

```bash
python3 Test/run-seed-tests.py
```

Esse executor testa o seed em cluster temporário e usa credenciais aleatórias
em memória. Não executa a carga no banco da aplicação nem lê inventários privados.
O procedimento de instalação nova e os três perfis estão no
[guia de demonstração](docs/dados-demonstracao.md).

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

