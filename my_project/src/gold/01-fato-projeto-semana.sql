-- Fato semanal do projeto: a curva de valor agregado (PV, EV, AC) de cada sexta-feira,
-- da semana do início do projeto até hoje (16/10/2026).
-- O histórico do avanço vem do status semanal: as ferramentas só guardam o % de hoje.

CREATE OR REFRESH MATERIALIZED VIEW lakehouse_vertice.gold.fato_projeto_semana (
  CONSTRAINT pv_nao_negativo EXPECT (pv >= 0) ON VIOLATION FAIL UPDATE,
  CONSTRAINT ev_ate_o_orcamento EXPECT (ev <= orcamento) ON VIOLATION FAIL UPDATE
)
COMMENT 'Uma linha por projeto e semana (sexta-feira), do início do projeto até 16/10/2026. pv = valor planejado (orçamento × fração das horas que o baseline previa concluídas até a semana), ev = valor agregado (orçamento × % concluído do status semanal), ac = custo real acumulado. spi = ev/pv (< 1 é atraso), cpi = ev/ac (< 1 é estouro), eac = orçamento/cpi. Traz o último farol publicado pelo gerente e as horas disponíveis, apontadas e ociosas da semana.'
AS
WITH semanas AS (
  -- uma sexta-feira por semana, da semana do início até hoje
  SELECT
    projeto_id,
    orcamento_custo AS orcamento,
    explode(sequence(
      date_add(to_date(date_trunc('WEEK', data_inicio)), 4),
      DATE'2026-10-16',
      INTERVAL 1 WEEK
    )) AS semana
  FROM projetos
),
fracao_tarefa AS (
  -- quanto de cada tarefa o baseline previa pronto naquela semana (0 a 1)
  SELECT
    s.projeto_id,
    s.semana,
    t.horas,
    greatest(0, least(1, coalesce(
      try_divide(datediff(s.semana, t.inicio_baseline), datediff(t.fim_baseline, t.inicio_baseline)),
      CASE WHEN s.semana >= t.fim_baseline THEN 1 ELSE 0 END   -- tarefa de duração zero
    ))) AS fracao
  FROM semanas s
  JOIN tarefas t ON t.projeto_id = s.projeto_id
),
planejado AS (
  SELECT projeto_id, semana, sum(horas * fracao) AS horas_planejadas, sum(horas) AS horas_totais
  FROM fracao_tarefa
  GROUP BY projeto_id, semana
),
status_da_semana AS (
  -- o % e o farol daquela sexta; projeto concluído não publica mais: vale o último
  SELECT
    s.projeto_id,
    s.semana,
    last_value(st.pct_concluido, true) OVER (PARTITION BY s.projeto_id ORDER BY s.semana) AS pct_concluido,
    last_value(st.farol, true)         OVER (PARTITION BY s.projeto_id ORDER BY s.semana) AS farol_do_gerente
  FROM semanas s
  LEFT JOIN status_semanal st
    ON st.projeto_id = s.projeto_id AND st.data_status = s.semana
),
custo_semanal AS (
  SELECT projeto_id, semana, sum(valor) AS valor
  FROM custos
  WHERE data <= DATE'2026-10-16'
  GROUP BY projeto_id, semana
),
custo_acumulado AS (
  -- tudo o que foi lançado até a semana
  SELECT s.projeto_id, s.semana, coalesce(sum(c.valor), 0) AS ac
  FROM semanas s
  LEFT JOIN custo_semanal c
    ON c.projeto_id = s.projeto_id AND c.semana <= s.semana
  GROUP BY s.projeto_id, s.semana
),
horas_semana AS (
  SELECT
    projeto_id,
    semana,
    sum(horas_disponiveis) AS horas_disponiveis,
    sum(horas_apontadas)   AS horas_apontadas
  FROM apontamentos
  GROUP BY projeto_id, semana
),
valores AS (
  SELECT
    s.projeto_id,
    s.semana,
    s.orcamento,
    round(s.orcamento * try_divide(p.horas_planejadas, p.horas_totais), 2) AS pv,
    round(s.orcamento * coalesce(st.pct_concluido, 0) / 100, 2)           AS ev,
    c.ac,
    st.pct_concluido,
    st.farol_do_gerente,
    h.horas_disponiveis,
    h.horas_apontadas
  FROM semanas s
  LEFT JOIN planejado p        ON p.projeto_id = s.projeto_id  AND p.semana = s.semana
  LEFT JOIN status_da_semana st ON st.projeto_id = s.projeto_id AND st.semana = s.semana
  LEFT JOIN custo_acumulado c  ON c.projeto_id = s.projeto_id  AND c.semana = s.semana
  LEFT JOIN horas_semana h     ON h.projeto_id = s.projeto_id  AND h.semana = s.semana
)
SELECT
  projeto_id,
  semana,
  orcamento,
  pct_concluido,
  pv,
  ev,
  ac,
  round(try_divide(ev, pv), 4)                                  AS spi,
  round(try_divide(ev, ac), 4)                                  AS cpi,
  round(try_divide(orcamento, round(try_divide(ev, ac), 4)), 2) AS eac,
  farol_do_gerente,
  coalesce(horas_disponiveis, 0)                                AS horas_disponiveis,
  coalesce(horas_apontadas, 0)                                  AS horas_apontadas,
  greatest(coalesce(horas_disponiveis, 0) - coalesce(horas_apontadas, 0), 0) AS horas_ociosas
FROM valores;
