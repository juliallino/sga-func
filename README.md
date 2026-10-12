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
- 📊 Geração de relatórios acadêmicos.
- 🔐 Controle de acesso por perfis de usuário (*Roles*).

---

## 👥 Equipe e Divisão de Papéis

| Integrante | Papel / Responsabilidade Primária |
|:---|:---|
| **JÚLIA LINO ARAÚJO** | Domínio, DevOps e Qualidade (CI/CD e testes) |
| **PEDRO DAVI CAMPOS VIEIRA** | Backend, Frontend e UX (Views HSX, Forms e SSR) |
| **DAVI TAVARES GADELHA** | Dados e Integração (Schemas, Migrations e Queries) |

---

## 🚀 Como Rodar o Projeto Localmente

**Sistema operacional:** Linux / Ubuntu

Siga os passos abaixo para clonar o repositório e executar a aplicação em seu ambiente local.

### 1. Pré-requisitos

Certifique-se de ter o **Nix** e o **direnv** instalados e configurados.

#### 1.1. Ativar as funcionalidades experimentais do Nix

Caso ainda não tenha ativado as funcionalidades experimentais do Nix, execute:

mkdir -p ~/.config/nix

echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf


#### 1.2. Configurar o PATH

Garanta que os binários do Nix estejam disponíveis no `PATH`:

echo 'export PATH="HOME/.nix−profile/bin:PATH"' >> ~/.bashrc

source ~/.bashrc


> **Observação:** Se as funcionalidades experimentais já estiverem configuradas, não é necessário adicionar a mesma configuração novamente.

### 2. Clonar o Repositório

Clone o repositório e acesse o diretório do projeto:

git clone https://github.com/juliallino/sga-func.git

cd sga-func


### 3. Iniciar o Ambiente de Desenvolvimento

Dentro do diretório do projeto, execute:

./start


Na primeira execução, o Nix baixará e configurará as dependências necessárias para o ambiente de desenvolvimento, incluindo as ferramentas do Haskell e do PostgreSQL, conforme definido na configuração do projeto.

Aguarde até que a inicialização seja concluída.

---

## 🌐 Endereços Locais

Após executar o comando `./start`, acesse os seguintes endereços no navegador:

| Serviço | Endereço |
|:---|:---|
| 🌍 Aplicação Web | [http://localhost:8000](http://localhost:8000) |
| 🛠️ IHP Dev Server / Schema Designer (IDE) | [http://localhost:8001](http://localhost:8001) |

> **Nota:** Os endereços estarão disponíveis enquanto os respectivos serviços estiverem em execução.

---

## 🧪 Testes Locais e CI/CD

Este repositório possui um fluxo de **Integração Contínua (CI)** configurado por meio do GitHub Actions.

O workflow está localizado em:

.github/workflows/nix-flake-check.yml


### Executar os testes localmente

Para executar as verificações definidas no Nix Flake, utilize:

nix flake check --impure


Esse comando executa as verificações e os testes definidos na configuração do projeto, conforme as condições do ambiente local.

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

