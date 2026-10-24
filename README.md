# First_DataBricks

Projeto feito acompanhando a Imersão Databricks + Claude Code (Projeto Farol). O bundle `vertice`, o app `minha-torre` e os prompts usados estão em [`my_project/`](my_project).

> Conteúdo abaixo copiado do README do curso: <https://github.com/lvgalvao/ImersaoControlTower/blob/main/README.md> (links relativos reescritos para apontar ao repositório original).

---

# 🔦 Projeto Farol · Imersão Databricks + Claude Code

**4 noites, 4 chapéus, 1 caso do começo ao fim.**

Você é o **único profissional de dados da Vértice Tecnologia**, uma empresa fictícia com 520 pessoas e 60 projetos
de clientes. Não tem time de dados: o analista, o engenheiro, o cientista e o engenheiro de IA são você. No primeiro dia, o dono pergunta uma coisa simples: *quais projetos estão
atrasados?* E ninguém sabe responder, porque cada gerente controla o seu projeto numa ferramenta diferente.

Em 4 noites, no **Databricks Free Edition** (grátis, na sua conta), você constrói a **Torre de Controle** que responde
ao dono: dos arquivos crus do Excel, do ClickUp e do MS Project até um app em que ele aprova decisões, com IA lendo
status semanais e contratos.

> **Imersão Jornada de Dados** · ao vivo no YouTube · **19 a 22 de outubro de 2026, às 19h30**
> Stack: Databricks Free Edition (serverless), SQL, Python, Lakeflow, Unity Catalog, AI/BI, Genie, Apps, Lakebase e Claude Code.
> Nunca programou? A noite 1 é toda no navegador.

---

## 🧭 O problema

A Vértice desenvolve e implanta sistemas para grandes clientes de varejo, financeiro, saúde, logística e indústria.
São 60 projetos, e cada gerente controla o seu do seu jeito: **20 em planilhas Excel, 25 no ClickUp e 15 no
MS Project**. O PMO consolida tudo à mão, toda sexta, e o farol do status semanal está quase todo verde.

Na sua primeira semana, o dono faz quatro perguntas:

| # | Pergunta do dono | O que a Torre mede |
|---|---|---|
| 1 | **Quais projetos estão atrasados, e de quais clientes?** | SPI, CPI, situação, farol calculado × farol do gerente |
| 2 | **Quanto esse atraso vai me custar?** | EAC, estouro previsto, margem projetada, atraso projetado |
| 3 | **Tenho gente parada enquanto outro projeto pede gente?** | utilização por pessoa e projeto, horas ociosas, causa no status |
| 4 | **O que vai dar errado no próximo mês, e o que eu faço agora?** | probabilidade de estouro em 30 dias, entregas de fornecedor atrasadas, contratos |

Regra de corte: **SPI ou CPI < 0,9 = atenção · < 0,8 = crítico.**

---

## 🔁 Ontem × agora: o que muda em 4 noites

**Ontem: o dado chega como cada ferramenta exporta.** A mesma informação ("quando a tarefa começa") vem como número
de série do Excel, como texto dentro de um JSON do ClickUp e como data ISO dentro de um XML do Project.

| Excel do PMO | ClickUp (JSON) | MS Project (XML) |
|---|---|---|
| ![planilha do Excel na bronze](https://raw.githubusercontent.com/lvgalvao/ImersaoControlTower/main/docs/img/ontem-excel-sujo.jpg) | ![export do ClickUp na bronze](https://raw.githubusercontent.com/lvgalvao/ImersaoControlTower/main/docs/img/ontem-clickup-json.jpg) | ![XML do MS Project na bronze](https://raw.githubusercontent.com/lvgalvao/ImersaoControlTower/main/docs/img/ontem-msproject-xml.jpg) |
| a data às vezes é texto (`06/03/2025`), às vezes número (`45700`) | responsável e campos personalizados dentro de listas JSON | baseline e datas aninhados, tarefas-resumo que somam duas vezes |

**Agora: uma tabela só, e as respostas em cima dela.**

| `silver.tarefas` (noite 2) | o schema `gold` (noites 2 a 4) |
|---|---|
| ![silver.tarefas com as 3 ferramentas](https://raw.githubusercontent.com/lvgalvao/ImersaoControlTower/main/docs/img/agora-silver-tarefas.jpg) | ![tabelas da gold](https://raw.githubusercontent.com/lvgalvao/ImersaoControlTower/main/docs/img/agora-gold.jpg) |
| as 3 ferramentas no mesmo formato: `projeto_id`, `ferramenta`, `fase`, `tarefa`, datas de verdade | as tabelas prontas para o dono: KPIs por projeto e semana, pessoas, causa do atraso, contratos, score do modelo |

**E o Genie (o "pergunte em português" do Databricks) passa de errar a acertar:**

| Noite 1 · sem curadoria, sobre a bronze | Noite 2 · curado, sobre a gold |
|---|---|
| ![Genie errando na noite 1](https://raw.githubusercontent.com/lvgalvao/ImersaoControlTower/main/docs/img/noite1-genie-erra.jpg) | ![Genie acertando na noite 2](https://raw.githubusercontent.com/lvgalvao/ImersaoControlTower/main/docs/img/noite2-genie.jpg) |
| responde com segurança, mas conta "27 atrasados" misturando projetos encerrados e mostra o PRJ-011, que é crítico, com custo **negativo** (em verde) | acha as duas SREs a ~5% no PRJ-007 enquanto o PRJ-011 está bloqueado por falta de SRE |

Tour completo pelas telas do Databricks que usamos: no fim de [**slides/imersao.html**](https://github.com/lvgalvao/ImersaoControlTower/blob/main/slides/imersao.html)
(workspace, notebook, serverless, warehouse, catálogo, volume, pipeline, job, lineage, metric view, Genie, MLflow,
Lakebase e Apps, um por slide, com print).

---

## 📖 Glossário de bolso

| Termo | Em uma frase |
|---|---|
| **SPI** | quanto do trabalho planejado já foi feito. 1 = no prazo; 0,8 = 20% atrás |
| **CPI** | quanto vale o que foi feito ÷ quanto custou. Abaixo de 1 = gastando mais do que entrega |
| **EAC / estouro** | quanto o projeto vai custar no fim, se seguir no ritmo de hoje; o estouro é o que passa do orçamento |
| **Melancia** | projeto verde por fora (farol do gerente) e vermelho por dentro (SPI abaixo de 0,9) |
| **Bronze · silver · gold** | o dado como chegou · limpo e unificado · pronto para responder ao dono |
| **Unity Catalog** | o "endereço" e a portaria de todo dado: `catálogo.schema.tabela`, com dono e permissão |
| **Volume** | uma pasta de arquivos (xlsx, json, xml, pdf) dentro do catálogo |
| **Pipeline / job** | o pipeline monta as tabelas; o job roda tudo em ordem, sozinho, todo dia |
| **Metric view** | onde mora a fórmula do KPI, para o dashboard, o Genie e o app usarem a mesma |
| **Genie** | o chat que transforma pergunta em português em SQL sobre as suas tabelas |
| **Lakebase** | um banco Postgres dentro do Databricks, para o app gravar decisões |
| **Claude Code** | o assistente de código no terminal que escreve, roda e corrige o projeto a partir dos prompts |

---

## 💼 Vantagens para o negócio

| Hoje, sem a Torre | Com a Torre | Ganho |
|---|---|---|
| PMO consolida Excel, ClickUp e Project à mão toda sexta | as 3 ferramentas num modelo só, atualizado todo dia | dias de consolidação viram zero |
| O farol do gerente decide o que o dono vê | farol calculado pelo número (SPI) | o projeto "melancia" aparece antes |
| Escopo cresce sem aditivo e ninguém cobra o cliente | alerta quando o CPI começa a cair | margem recuperada |
| SRE parado num projeto, faltando em outro | ociosidade por pessoa e projeto, cruzada com o status | realocar em vez de contratar |
| Decisão de realocação por WhatsApp e e-mail | aprovação no app, gravada com usuário e horário | decisão rastreável e auditável |

Medido no dado da Vértice ao fim das 4 noites:

| O que a Torre mostra | Valor |
|---|---|
| Projetos em risco · críticos | **17 de 41 · 7**, espalhados nas três ferramentas |
| Estouro previsto se nada mudar | **R$ 6,47 mi** |
| Farol verde com SPI abaixo de 0,9 | **4 projetos** (32 faróis verdes; pelo número, 24 projetos ok) |
| Gente parada | **2 SREs seniores a ~5%** no PRJ-007, enquanto o PRJ-011 pede SRE há 12 semanas |
| Antecedência do modelo de estouro | **9 de 10** estouros avisados, em média **41 dias** antes (AUC 0,92; a regra atual: 0,50) |
| Genie em português | **20/20** (portfólio) e **10/10** (contratos) no benchmark |
| Multa cobrável da CodeForge pelo contrato | **R$ 1,12 mi** (0,5% ao dia, teto de 10%) |
| Entregas de fornecedor em atraso | **5** (todas da CodeForge) |
| ROI do pitch (premissas explícitas) | **≈ R$ 3,0 mi** no ano 1 contra R$ 0,4 mi de custo |

**Para o aluno:** um projeto completo de ponta a ponta no GitHub, o tipo de entrega que toda empresa que vive de
projeto compra, e o pitch pronto para vender para o dono.

---

## 🏛️ Arquitetura

```
 FONTES                         LAKEHOUSE · UNITY CATALOG · lakehouse_vertice              CONSUMO
 ──────                         ──────────────────────────────────────────────            ────────────────────
 Excel (20 .xlsx)          ─┐   ┌──────────┐   ┌────────────────┐   ┌───────────────┐     ┌ AI/BI Dashboards
 ClickUp (25 .json)         │   │  BRONZE  │   │     SILVER     │   │     GOLD      │     │
 MS Project (15 .xml)       ├──▶│ como veio│──▶│ as 3 ferramen- │──▶│ KPIs por      │──┬─▶├ Genie Agent
 PMO: status semanal        │   │ read_files│   │ tas num modelo │   │ projeto e     │  │  │   (perguntas do dono)
 RH · timesheet             │   │ lê tudo  │   │ só, testado    │   │ semana        │  │  ├ App da Torre
 Financeiro · compras       │   └──────────┘   │ ai_extract nos │   │ Metric Views  │  │  │   + Lakebase (decisões)
 Contratos em PDF ──────────┘     noite 1      │ textos         │   └───────────────┘  │  └ Agente de contratos
                                               └────────────────┘        noite 2       │      (noite 4)
                                                     noite 2                           │
                                     Modelo de estouro em 30 dias (MLflow, UC) ◀───────┘ noite 3
```

Os KPIs são definidos **uma vez** (Metric Views no Unity Catalog) e reusados no dashboard, no Genie, no app e no agente.

---

## 🗓️ As 4 noites

| Noite | Data | Chapéu | A pergunta | O que existe no fim | Como constrói | Pasta |
|---|---|---|---|---|---|---|
| **1** | seg 19/10 | Analista · SQL | O que o Databricks faz? Quem está atrasado? | bronze lendo Excel, JSON e XML, ranking de atraso das 3 ferramentas, R$ de estouro, 1º dashboard, Genie que erra | navegador (SQL Editor) | [`aula-01-analista-sql`](https://github.com/lvgalvao/ImersaoControlTower/blob/main/aulas/aula-01-analista-sql) |
| **2** | ter 20/10 | Engenheiro de Dados · Python | E se o dado não estiver no meu computador? | aquecimento de Python, data lake (S3/boto3 no Supabase) → raw → bronze, API de feriados, job de ingestão às 6h | notebooks no Databricks | [`aula-02-python-engenheiro`](https://github.com/lvgalvao/ImersaoControlTower/blob/main/aulas/aula-02-python-engenheiro) |
| **3** | qua 21/10 | Analytics Engineer · modelagem | Como as três ferramentas viram uma, com teste? | bundle, silver que integra as 3 ferramentas, gold (fotografia × filme), testes e a metric view mv_projetos | prompts no Claude Code | [`aula-03-modelagem-claude-code`](https://github.com/lvgalvao/ImersaoControlTower/blob/main/aulas/aula-03-modelagem-claude-code) |
| **4** | qui 22/10 | Engenheiro de IA · produtos de dados | E o dono, que não escreve SQL? | IA no texto do status, agente de contratos, dashboard + Genie curado, app da Torre, pitch de 3 min | prompts no Claude Code | [`aula-04-produtos-de-dados-ia`](https://github.com/lvgalvao/ImersaoControlTower/blob/main/aulas/aula-04-produtos-de-dados-ia) |

**Apresentações** (abra o `.html` no navegador; ← → navega, F tela cheia):
[**slides/imersao.html**](https://github.com/lvgalvao/ImersaoControlTower/blob/main/slides/imersao.html), um deck só para as 4 noites: o case, cada noite com passo a passo,
prompts e um print de cada entregável, e no fim o tour pelos recursos do Databricks. Versão editável em PowerPoint
(importa no Canva): [`slides/pptx/`](https://github.com/lvgalvao/ImersaoControlTower/blob/main/slides/pptx).

```
  noite 1             noite 2               noite 3                noite 4
  ───────             ───────               ───────                ───────
  junta à mão      →  integra num       →   vira previsão     →    vira produto
  as 3 ferramentas    pipeline que roda     "quais vão             app, agente e o
  e o Genie erra      e define o KPI        estourar?"             pitch para o dono
```

### O que aparece na tela, noite a noite

| Noite 1 · o primeiro painel, sobre a bronze | Noite 2 · o pipeline que integra as 3 ferramentas |
|---|---|
| ![dashboard da noite 1](https://raw.githubusercontent.com/lvgalvao/ImersaoControlTower/main/docs/img/noite1-dashboard.jpg) | ![pipeline vertice_medalhao](https://raw.githubusercontent.com/lvgalvao/ImersaoControlTower/main/docs/img/noite2-pipeline.jpg) |
| **Noite 2 · o painel do dono, sobre a gold** | **Noite 2 · o job que roda tudo sozinho** |
| ![dashboard Portfólio](https://raw.githubusercontent.com/lvgalvao/ImersaoControlTower/main/docs/img/noite2-dashboard.jpg) | ![job vertice_farol](https://raw.githubusercontent.com/lvgalvao/ImersaoControlTower/main/docs/img/noite2-job.jpg) |
| **Noite 3 · o modelo registrado, com @prod** | **Noite 3 · o score de hoje, com o motivo** |
| ![modelo no Unity Catalog](https://raw.githubusercontent.com/lvgalvao/ImersaoControlTower/main/docs/img/noite3-modelo.jpg) | ![score de estouro](https://raw.githubusercontent.com/lvgalvao/ImersaoControlTower/main/docs/img/noite3-score.jpg) |
| **Noite 4 · o Genie que lê contrato** | **Noite 4 · o Lakebase que guarda a decisão do app** |
| ![Genie de contratos](https://raw.githubusercontent.com/lvgalvao/ImersaoControlTower/main/docs/img/noite4-genie-contratos.jpg) | ![Lakebase farol-torre](https://raw.githubusercontent.com/lvgalvao/ImersaoControlTower/main/docs/img/recurso-lakebase-projeto.jpg) |

Cada pasta é **autocontida** (README, roteiro, verificação e checkpoint). Perdeu uma noite? Comece da próxima.

---

## 🚀 Comece por aqui (5 minutos, sem instalar nada)

1. Crie a conta grátis: [databricks.com/learn/free-edition](https://www.databricks.com/learn/free-edition).
2. No Databricks: **Workspace → Create → Git folder** → `https://github.com/lvgalvao/ImersaoControlTower`.
3. Abra `aulas/aula-01-analista-sql/00-carregar-dados` → **Run all**. O catálogo nasce e os dados são gerados direto no volume.
4. Abra `aulas/aula-01-analista-sql/01-ingestao-bronze.sql` no **SQL Editor** → rode tudo.
5. Rode o exemplo 05 e depois `aulas/aula-01-analista-sql/99-verificacao.sql`. As 18 linhas devem dar `ok`.

Daí em diante, siga o [README da noite 1](https://github.com/lvgalvao/ImersaoControlTower/blob/main/aulas/aula-01-analista-sql/README.md).

### Para as noites 2 a 4 (terminal)

```bash
git clone https://github.com/lvgalvao/ImersaoControlTower.git && cd ImersaoControlTower

# CLI do Databricks (>= 0.250) e login: cria o profile e salva a credencial
brew install databricks/tap/databricks        # ou: curl -fsSL https://raw.githubusercontent.com/databricks/setup-cli/main/install.sh | sh
databricks auth login --profile imersao        # escolha um nome e use SEMPRE --profile

# Claude Code
npm install -g @anthropic-ai/claude-code
claude                                         # na raiz do repositório
```

As **skills oficiais do Databricks** para o Claude Code já vêm no repositório (`.claude/skills/`). Para atualizar:
`databricks aitools update`.

Os prompts de cada noite, na ordem e prontos para colar: [`PROMPTS.md`](https://github.com/lvgalvao/ImersaoControlTower/blob/main/PROMPTS.md).

---

## 🗄️ O dataset

Gerado por [`material/gerar_dataset.py`](https://github.com/lvgalvao/ImersaoControlTower/blob/main/material/gerar_dataset.py): só biblioteca padrão do Python, **seed fixa 42**,
cerca de 7 MB, em menos de 1 segundo. O "hoje" do dataset é **16/10/2026**. Todo aluno gera exatamente os mesmos bytes.

```bash
python3 material/gerar_dataset.py --saida ./dados --seed 42
python3 material/validar_padroes.py --dados ./dados      # junta as 3 ferramentas e confere os 5 padrões
```

| Sistema | O que vem | Linhas |
|---|---|---:|
| PMO | `projetos` · `status_semanal` (texto livre e farol) | 60 · 3.911 |
| Excel | 20 planilhas `.xlsx`, uma por projeto | 1.663 |
| ClickUp | 25 exports `.json` da API | 2.119 tarefas |
| MS Project | 15 arquivos `.xml` | 1.260 tarefas |
| RH e timesheet | `colaboradores` · `apontamentos` | 523 · 30.883 |
| Financeiro | `custos` | 23.640 |
| Compras | `entregas_fornecedor` | 640 |
| Documentos | contratos de fornecedor e SaaS (PDF, lidos na noite 4) | 8 |

**O dado é simulado, não sorteado:** cada projeto avança semana a semana. Freeze, falta de SRE e squad com
rotatividade atrasam; cada avanço consome horas e gera custo. Por isso SPI, CPI e ociosidade saem
coerentes entre si. **Padrões embutidos:**

1. 8 projetos com CPI caindo a partir do 6º mês (escopo cresce sem aditivo);
2. o change freeze da Black Friday (01/11 a 10/01) trava os 3 projetos de e-commerce;
3. a consultoria CodeForge entrega com prazo 41% acima do prometido, e aparece escrita de 4 jeitos;
4. dois SREs seniores ociosos num projeto que ainda está no desenho, enquanto o status de outro pede SRE toda semana;
5. dois squads com rotatividade alta e os piores SPI da carteira.

**A sujeira é proposital** e é o conteúdo da noite 2: cada ferramenta com seu formato de data e de percentual,
linha de TOTAL na planilha, tarefas-resumo no Project, status escrito de 12 jeitos no ClickUp, ferramenta escrita
de 8 jeitos no PMO, vírgula decimal, estorno negativo, pessoa duplicada no RH e status vazio. Não "conserte" o gerador.

---

## 📁 Estrutura

```
aulas/
├── aula-01-analista-sql/          navegador: catálogo, bronze das 3 ferramentas, 6 exemplos SQL, dashboard, Genie sem curadoria
├── aula-02-python-engenheiro/    notebooks: aquecimento de Python, data lake (boto3) → raw → bronze, API, job
├── aula-03-modelagem-claude-code/ Claude Code: bundle, silver, gold, testes, metric view
└── aula-04-produtos-de-dados-ia/  Claude Code: IA no texto, contratos, dashboard + Genie, app da Torre, pitch
material/
├── gerar_dataset.py           o gerador (seed 42)
├── validar_padroes.py         o gabarito: junta as 3 ferramentas e confere a história
├── xlsx_simples.py            escreve e lê .xlsx sem dependência
├── pdf_simples.py             escreve os PDFs sem dependência
└── PRD-torre-de-controle.md   a especificação da imersão
scripts/
├── run_sql.py                 roda um .sql no warehouse, statement por statement (API de statements)
├── genie.py                   publica um Genie a partir de JSON, pergunta e roda benchmark
├── gerar_notebooks.py         .sql dos exemplos → notebooks resolvidos e em branco
├── gerar_slides.py            fragmento de slides → apresentação HTML no visual da Jornada
└── gerar_prompts.py           monta o PROMPTS.md a partir dos prompts de cada noite
slides/                        as apresentações de cada noite (abra o .html no navegador)
.claude/skills/                as skills oficiais do Databricks para o Claude Code
```

---

## ✅ Testes

| O que | Comando | Esperado |
|---|---|---|
| Dataset reproduzível | gerar duas vezes e comparar o sha256 que o validador imprime | idênticos |
| Padrões da história | `python3 material/validar_padroes.py --dados ./dados` | `TODOS OS PADRÕES OK` |
| Noite 1 no workspace | `python3 scripts/run_sql.py aulas/aula-01-analista-sql/99-verificacao.sql --profile P` | 22 × `ok` |
| Genie da noite 1 | `python3 scripts/genie.py perguntar "Farol · Noite 1 (bronze, sem curadoria)" "Quanto esse atraso vai me custar?" --profile P` | resposta errada, de propósito |
| Job completo (noites 2 e 3) | `cd aulas/aula-03-modelagem-claude-code/claude-code/vertice && databricks bundle deploy --profile P && databricks bundle run vertice_farol --profile P` | 8 tarefas verdes, ~4 a 5 min |
| Noite 2 | `python3 scripts/run_sql.py aulas/aula-03-modelagem-claude-code/claude-code/prd/99-verificacao.sql --profile P` | 20 × `ok` |
| Genie da noite 4 | `python3 scripts/genie.py benchmark "Farol · Diretoria" aulas/aula-04-produtos-de-dados-ia/prd/genie-benchmark-diretoria.json --profile P` | 20/20 (18/10) |
| Noite 4 (modelo, metric view, app) | `python3 scripts/run_sql.py aulas/aula-04-produtos-de-dados-ia/99-verificacao.sql --profile P` | 23 × `ok` |
| Bônus: contratos | `python3 scripts/run_sql.py aulas/aula-04-produtos-de-dados-ia/bonus/99-verificacao-contratos.sql --profile P` e `python3 scripts/genie.py benchmark "Farol · Diretoria + Contratos" aulas/aula-04-produtos-de-dados-ia/bonus/genie-benchmark-contratos.json --profile P` | 11 × `ok` · 10/10 |
| App + Lakebase | `cd aulas/aula-04-produtos-de-dados-ia/torre-app && npm test` e `python3 scripts/ver_decisoes.py` | 5 testes; a aprovação aparece no Postgres |

---

## 🧪 O que funciona no Free Edition (testado em 18/10/2026)

| Recurso | Status | Como usamos |
|---|---|---|
| Unity Catalog, volumes, SQL warehouse serverless | ✅ | `CREATE CATALOG` via SQL (a API recusa no Free Edition) |
| `read_files` com Excel, JSON e XML | ✅ | as 3 ferramentas entram na bronze sem conversão |
| Notebook serverless com internet | ✅ | o `00-carregar-dados` roda o gerador dentro do workspace |
| `ai_extract`, `ai_classify`, `ai_query` | ✅ | causa do atraso a partir do texto do status semanal |
| Metric Views | ✅ | só pela API de statements: o `aitools query` achata a indentação do YAML |
| AI/BI Dashboards, Genie Agents (com modo Agent) | ✅ | dashboard como JSON e Genie como JSON |
| Databricks Apps | ✅ | app da Torre (noite 4) |
| **Lakebase** (Postgres) | ✅ **novo**: em agosto não existia | decisões gravadas pelo app |
| `ai_parse_document` em PDF | ✅ | os contratos viram tabela |
| Lakeflow Declarative Pipelines (SQL) com `EXPECT` | ✅ | silver e gold |
| Registro de modelo no Unity Catalog | ⚠️ falha com o MLflow do serverless (`s3:PutObject ... explicit deny`) | `%pip install -U "mlflow-skinny[databricks]>=2.21,<3"` + `restartPython()` |
| Knowledge Assistant e Supervisor Agent | ❌ "legacy", não cria mais | agente de contratos com `ai_parse_document` + Genie |
| Databricks Apps | ⚠️ no máximo 3 apps por workspace | libere um antes do deploy da noite 4 |
| Endpoint de modelo próprio (Model Serving) | ❌ só modelos de base | o score de estouro roda em lote e grava na gold |

---

## 🔑 Convenções

- Catálogo **`lakehouse_vertice`**, schemas `bronze` / `silver` / `gold`, volume `bronze.raw`.
- Tabelas e colunas em snake_case e português.
- "Hoje" é sempre `DATE'2026-10-16'`, nunca `current_date()`.
- Sempre `--profile` nos comandos do Databricks.
- A bronze guarda o dado **como veio**. Limpeza e integração são na silver.

---

Feito pela [Jornada de Dados](https://suajornadadedados.com.br). Dados e empresas fictícios.
