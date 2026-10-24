-- AS TRÊS FERRAMENTAS VIRAM UMA.
-- Uma visão temporária por ferramenta, todas com as MESMAS colunas:
-- projeto_id, ferramenta, id_na_ferramenta, fase, tarefa, responsavel,
-- inicio_baseline, fim_baseline, inicio_real, fim_real, pct_como_veio, horas, status_na_ferramenta
-- e no fim um UNION ALL numa materialized view.

-- ---------------------------------------------------------------------------
-- Excel: 20 planilhas, tudo texto
-- ---------------------------------------------------------------------------
CREATE TEMPORARY VIEW tarefas_excel
COMMENT 'Tarefas das planilhas Excel, limpas e no formato comum'
AS
SELECT
  -- de-para pelo nome do arquivo; se não casar (código vazio ou arquivo sem acento), o PRJ-xxx do nome
  coalesce(p.projeto_id, regexp_extract(e.arquivo, 'PRJ-[0-9]{3}', 0)) AS projeto_id,
  'excel'                                                              AS ferramenta,
  CAST(e.id AS STRING)                                                 AS id_na_ferramenta,
  e.fase,
  e.tarefa,
  e.responsavel,
  -- data com '/' é dd/MM/yyyy; sem '/' é número de série do Excel
  CASE WHEN e.inicio_previsto LIKE '%/%' THEN to_date(e.inicio_previsto, 'dd/MM/yyyy')
       ELSE date_add(DATE'1899-12-30', CAST(e.inicio_previsto AS INT)) END   AS inicio_baseline,
  CASE WHEN e.termino_previsto LIKE '%/%' THEN to_date(e.termino_previsto, 'dd/MM/yyyy')
       ELSE date_add(DATE'1899-12-30', CAST(e.termino_previsto AS INT)) END  AS fim_baseline,
  CASE WHEN e.inicio_real LIKE '%/%' THEN to_date(e.inicio_real, 'dd/MM/yyyy')
       ELSE date_add(DATE'1899-12-30', CAST(e.inicio_real AS INT)) END       AS inicio_real,
  CASE WHEN e.termino_real LIKE '%/%' THEN to_date(e.termino_real, 'dd/MM/yyyy')
       ELSE date_add(DATE'1899-12-30', CAST(e.termino_real AS INT)) END      AS fim_real,
  -- '45%' e '10,5%': tira o '%' e troca a vírgula; 0.45: é fração, × 100
  CASE WHEN contains(e.pct_concluido, '%')
       THEN CAST(replace(replace(e.pct_concluido, '%', ''), ',', '.') AS DOUBLE)
       ELSE CAST(e.pct_concluido AS DOUBLE) * 100 END                  AS pct_como_veio,
  -- '40h' → 40
  CAST(replace(e.horas_previstas, 'h', '') AS DOUBLE)                  AS horas,
  CAST(NULL AS STRING)                                                 AS status_na_ferramenta
FROM lakehouse_vertice.bronze.excel_tarefas e
LEFT JOIN projetos p
  ON p.ferramenta = 'excel' AND p.codigo_ferramenta = e.arquivo
-- a última linha de cada planilha é o TOTAL: soma as de cima
WHERE e.tarefa <> 'TOTAL';

-- ---------------------------------------------------------------------------
-- ClickUp: 25 listas, datas em milissegundos, % e baseline em custom_fields
-- ---------------------------------------------------------------------------
CREATE TEMPORARY VIEW tarefas_clickup
COMMENT 'Tarefas das listas do ClickUp, limpas e no formato comum'
AS
SELECT
  -- de-para pelo list_id; se o código faltar no cadastro, pelo nome da lista
  coalesce(p_id.projeto_id, p_nome.projeto_id)                          AS projeto_id,
  'clickup'                                                             AS ferramenta,
  c.id                                                                  AS id_na_ferramenta,
  filter(c.custom_fields, f -> f.name = 'Fase')[0].value                AS fase,
  c.name                                                                AS tarefa,
  c.assignees[0].username                                               AS responsavel,
  to_date(timestamp_millis(CAST(filter(c.custom_fields, f -> f.name = 'Início baseline')[0].value AS BIGINT))) AS inicio_baseline,
  to_date(timestamp_millis(CAST(filter(c.custom_fields, f -> f.name = 'Fim baseline')[0].value AS BIGINT)))    AS fim_baseline,
  to_date(timestamp_millis(CAST(c.start_date AS BIGINT)))               AS inicio_real,
  to_date(timestamp_millis(CAST(c.date_done AS BIGINT)))                AS fim_real,
  CAST(filter(c.custom_fields, f -> f.name = 'Progresso (%)')[0].value AS DOUBLE) AS pct_como_veio,
  -- time_estimate vem em milissegundos
  c.time_estimate / 3600000.0                                           AS horas,
  -- 12 grafias de status viram 3
  CASE
    WHEN lower(c.status.status) IN ('done', 'closed', 'concluído')                       THEN 'concluida'
    WHEN lower(c.status.status) IN ('to do', 'todo', 'backlog', 'a fazer')               THEN 'a_fazer'
    WHEN lower(c.status.status) IN ('in progress', 'doing', 'em andamento', 'review')    THEN 'em_andamento'
  END                                                                   AS status_na_ferramenta
FROM lakehouse_vertice.bronze.clickup_tarefas c
LEFT JOIN projetos p_id
  ON p_id.ferramenta = 'clickup' AND p_id.codigo_ferramenta = c.list_id
LEFT JOIN projetos p_nome
  ON p_nome.ferramenta = 'clickup' AND p_nome.codigo_ferramenta IS NULL AND p_nome.nome_projeto = c.list_name;

-- ---------------------------------------------------------------------------
-- MS Project: 15 XML, com tarefas-resumo e fase na hierarquia
-- ---------------------------------------------------------------------------
CREATE TEMPORARY VIEW tarefas_msproject
COMMENT 'Tarefas dos cronogramas MS Project (sem as tarefas-resumo), limpas e no formato comum'
AS
WITH com_fase AS (
  -- a fase é a última tarefa-resumo de nível 1 antes da tarefa (calculada antes de tirar os resumos)
  SELECT
    m.*,
    last_value(CASE WHEN m.OutlineLevel = 1 THEN m.Name END, true)
      OVER (PARTITION BY m.arquivo ORDER BY m.UID) AS fase
  FROM lakehouse_vertice.bronze.msproject_tarefas m
)
SELECT
  p.projeto_id,
  'msproject'                                              AS ferramenta,
  CAST(t.UID AS STRING)                                    AS id_na_ferramenta,
  t.fase,
  t.Name                                                   AS tarefa,
  CAST(NULL AS STRING)                                     AS responsavel,
  to_date(t.Baseline.Start)                                AS inicio_baseline,
  to_date(t.Baseline.Finish)                               AS fim_baseline,
  to_date(t.ActualStart)                                   AS inicio_real,
  to_date(t.ActualFinish)                                  AS fim_real,
  CAST(t.PercentComplete AS DOUBLE)                        AS pct_como_veio,
  -- 'PT40H0M0S' → 40
  CAST(regexp_extract(t.Work, 'PT([0-9]+)H', 1) AS DOUBLE) AS horas,
  CAST(NULL AS STRING)                                     AS status_na_ferramenta
FROM com_fase t
LEFT JOIN projetos p
  ON p.ferramenta = 'msproject' AND p.codigo_ferramenta = t.arquivo
-- as tarefas-resumo somam as de baixo: ficam fora
WHERE t.Summary = 0;

-- ---------------------------------------------------------------------------
-- O modelo único
-- ---------------------------------------------------------------------------
CREATE OR REFRESH MATERIALIZED VIEW tarefas (
  CONSTRAINT achou_o_projeto EXPECT (projeto_id IS NOT NULL) ON VIOLATION FAIL UPDATE,
  CONSTRAINT pct_entre_0_e_100 EXPECT (pct_concluido BETWEEN 0 AND 100) ON VIOLATION FAIL UPDATE,
  CONSTRAINT horas_positivas EXPECT (horas > 0) ON VIOLATION FAIL UPDATE
)
COMMENT 'Todas as tarefas dos 60 projetos num modelo só: Excel (20 projetos), ClickUp (25) e MS Project (15). Uma linha por tarefa, com baseline, datas reais, % concluído (limitado a 100, com a flag pct_veio_acima_de_100) e horas previstas. É a fotografia de hoje do avanço de cada projeto.'
AS
WITH todas AS (
  SELECT * FROM tarefas_excel
  UNION ALL
  SELECT * FROM tarefas_clickup
  UNION ALL
  SELECT * FROM tarefas_msproject
)
SELECT
  concat_ws('-', projeto_id, ferramenta, id_na_ferramenta) AS tarefa_id,
  projeto_id,
  ferramenta,
  id_na_ferramenta,
  fase,
  tarefa,
  responsavel,
  inicio_baseline,
  fim_baseline,
  inicio_real,
  fim_real,
  least(pct_como_veio, 100)  AS pct_concluido,
  pct_como_veio,
  pct_como_veio > 100        AS pct_veio_acima_de_100,
  horas,
  status_na_ferramenta
FROM todas;
