-- Pessoas e timesheet.

CREATE OR REFRESH MATERIALIZED VIEW colaboradores
COMMENT 'Cadastro das 520 pessoas da Vértice, uma por linha: papel, senioridade, custo por hora, admissão e desligamento (vazio = ativo). Os 3 cadastros duplicados (COL0102, COL0257, COL0433, repetidos em CAIXA ALTA) ficam só com a versão em minúsculas.'
AS
WITH numerados AS (
  SELECT
    *,
    -- o cadastro bom é o que tem papel em minúsculas
    row_number() OVER (PARTITION BY colaborador_id ORDER BY papel = lower(papel) DESC, nome) AS n
  FROM lakehouse_vertice.bronze.colaboradores
)
SELECT
  colaborador_id,
  nome,
  papel,
  senioridade,
  CAST(custo_hora AS DECIMAL(10, 2))  AS custo_hora,
  to_date(data_admissao)              AS data_admissao,
  to_date(nullif(trim(data_desligamento), '')) AS data_desligamento
FROM numerados
WHERE n = 1;

CREATE OR REFRESH MATERIALIZED VIEW apontamentos
COMMENT 'Timesheet semanal: horas disponíveis e horas apontadas por pessoa, projeto e semana. semana é a sexta-feira (semana_inicio + 4), para casar com o status semanal.'
AS
SELECT
  colaborador_id,
  projeto_id,
  to_date(semana_inicio)                    AS semana_inicio,
  date_add(to_date(semana_inicio), 4)       AS semana,
  CAST(horas_disponiveis AS DECIMAL(6, 1))  AS horas_disponiveis,
  CAST(horas_apontadas AS DECIMAL(6, 1))    AS horas_apontadas
FROM lakehouse_vertice.bronze.apontamentos;
