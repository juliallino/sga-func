## Testes de Carga e Estresse (Benchmarking) — Sprint 5

### 1. Objetivo
Avaliar a capacidade de vazão (*throughput*), a estabilidade sob concorrência e o comportamento de latência das rotas autenticadas do **SGA-Func** (arquitetura funcional em Haskell/IHP + Warp + PostgreSQL/Hasql) diante de picos de acesso simultâneo.

---

### 2. Ambiente e Metodologia de Teste
* **Ferramenta de Benchmarking:** `wrk` (HTTP benchmarking tool multithread com suporte a histogramas de latência `--latency`).
* **Stack Avaliada:** Servidor web **Warp** (GHC Runtime) com framework **IHP** (`IHP_ENV=Development`) e pool de conexões **Hasql** conectado ao **PostgreSQL** via socket Unix local.
* **Autenticação:** Todas as requisições foram executadas com sessão autenticada válida via cabeçalho HTTP `Cookie` (`SESSION=...`) com perfil administrativo (`RoleAdmin`), garantindo que o fluxo atravessasse o middleware de autenticação, consultas ao banco de dados e renderização server-side (HSX).
* **Parâmetros de Execução:**
  * **Duração por cenário:** `30s`
  * **Threads do gerador de carga:** `4` (`-t4`)
  * **Cenário 1 (Carga Base — Cursos):** `100` conexões simultâneas (`-c100`) na rota `GET /Courses`
  * **Cenário 2 (Carga Base — Estudantes):** `100` conexões simultâneas (`-c100`) na rota `GET /Students`
  * **Cenário 3 (Estresse / Pico de Concorrência):** `200` conexões simultâneas (`-c200`) na rota `GET /Courses`

---

### 3. Resultados Obtidos

| Cenário | Rota Avaliada | Conexões (`-c`) | Req. Totais (30s) | Vazão (`Req/s`) | Latência Média | Latência p50 | Latência p90 | Latência p99 | Transferência | Erros (HTTP / Socket) |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **1. Carga Base** | `GET /Courses` | 100 | 46.121 | **1.533,78 req/s** | 65,10 ms | 67,59 ms | 78,22 ms | **102,02 ms** | 11,64 MB/s | **0 (0,00%)** |
| **2. Carga Base** | `GET /Students` | 100 | 43.267 | **1.438,78 req/s** | 69,40 ms | 70,77 ms | 87,52 ms | **109,21 ms** | 10,97 MB/s | **0 (0,00%)** |
| **3. Estresse (Pico)** | `GET /Courses` | 200 | 38.569 | **1.282,29 req/s** | 156,25 ms | 149,18 ms | 184,53 ms | **328,44 ms** | 9,73 MB/s | **0 (0,00%)** |

> **Total consolidado:** **127.957 requisições** processadas ao longo de 90 segundos de teste contínuo sem nenhuma falha de socket, *timeout* ou resposta HTTP `4xx`/`5xx`.

---

### 4. Análise de Desempenho e Identificação de Gargalos

#### 4.1. Resiliência e Taxa de Erro Zero
Mesmo operando em modo de desenvolvimento (`IHP_ENV=Development` — que inclui verificações adicionais e monitoramento de arquivos), o servidor Warp/GHC manteve **100% de disponibilidade** e **0% de erros** em todos os cenários. Com 100 usuários simultâneos, o tempo de resposta no percentil 99 (`p99`) permaneceu na faixa de **102 ms a 109 ms**, garantindo experiência interativa fluida.

#### 4.2. Comportamento sob Saturação (`-c100` vs. `-c200`)
Ao dobrar a concorrência de `100` para `200` conexões simultâneas em `/Courses`:
* A vazão teve uma redução moderada de **16,4%** (de `1.533,78 req/s` para `1.282,29 req/s`).
* A latência média aumentou **2,4x** (de `65,10 ms` para `156,25 ms`), enquanto o `p99` atingiu `328,44 ms`.

**Diagnóstico do Gargalo:**
O crescimento proporcional da latência sem ocorrência de erros indica **enfileiramento na disputa por recursos compartilhados**, especificamente:
1. **Contenção no Pool de Conexões (`Hasql.Pool`):** O tamanho padrão do pool de conexões com o PostgreSQL limita o número de consultas simultâneas ativas. Sob 200 conexões concorrentes, as *green threads* do GHC aguardam na fila pela liberação de uma conexão do pool antes de executar a consulta SQL e montar a view HSX.
2. **Contenção de CPU no Ambiente Local (WSL2):** A execução simultânea do gerador de carga (`wrk` com 4 threads), do servidor Warp e do banco PostgreSQL na mesma instância local compartilha os mesmos núcleos de processamento.

#### 4.3. Comparação entre Rotas (`GET /Courses` vs. `GET /Students`)
Sob a mesma carga de 100 conexões, `GET /Students` apresentou vazão **6,2% inferior** a `GET /Courses` (`1.438,78 req/s` contra `1.533,78 req/s`) e latência média `4,3 ms` maior, refletindo o custo marginal de serialização e renderização HTML dos campos adicionais da entidade de estudantes.

---

### 5. Recomendações de Otimização (Próximos Passos)
1. **Dimensionamento do Pool de Banco de Dados:** Ajustar o parâmetro `maxConnections` do pool do `Hasql` em `Config/Config.hs` de acordo com o número de núcleos disponíveis em produção para reduzir o tempo de espera em fila sob picos (`-c200+`).
2. **Compilação em Modo Produção (`IHP_ENV=Production`):** Executar o binário otimizado (`-O2` sem overhead de *hot-reload*) e com assets estáticos servidos via proxy reverso (Nginx/Caddy) para elevar o teto de vazão e reduzir a latência de cauda (`p99`).
3. **Paginação e Índices:** Manter paginação nas listagens principais (`/Students`, `/Enrollments`, `/Grades`) e índices nas chaves estrangeiras para evitar degradação linear conforme o volume de registros crescer.