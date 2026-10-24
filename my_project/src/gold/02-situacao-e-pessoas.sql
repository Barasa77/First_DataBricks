-- A fotografia de hoje de cada projeto e a utilização das pessoas.

CREATE OR REFRESH MATERIALIZED VIEW lakehouse_vertice.gold.projeto_situacao_atual
COMMENT 'Fotografia de 16/10/2026 dos 60 projetos (uma linha por projeto): cadastro (cliente, segmento, tipo, ferramenta, gerente, contrato, orçamento, prazo) e os KPIs de hoje calculados sobre as tarefas das ferramentas: pv, ev, ac, spi, cpi, eac, estouro previsto, margem projetada, atraso projetado em dias e término projetado. situacao: concluído / crítico (SPI ou CPI < 0,8) / atenção (< 0,9) / ok. farol_calculado pela regra do manual (verde SPI >= 0,95, amarelo >= 0,90). melancia = em andamento, farol do gerente verde e SPI < 0,9.'
AS
WITH tarefas_hoje AS (
  -- quanto o baseline previa pronto hoje e quanto está pronto, em horas
  SELECT
    projeto_id,
    sum(horas) AS horas_totais,
    sum(horas * greatest(0, least(1, coalesce(
      try_divide(datediff(DATE'2026-10-16', inicio_baseline), datediff(fim_baseline, inicio_baseline)),
      CASE WHEN DATE'2026-10-16' >= fim_baseline THEN 1 ELSE 0 END
    )))) AS horas_planejadas,
    sum(horas * pct_concluido / 100) AS horas_agregadas
  FROM tarefas
  GROUP BY projeto_id
),
custo_hoje AS (
  SELECT projeto_id, sum(valor) AS ac
  FROM custos
  WHERE data <= DATE'2026-10-16'
  GROUP BY projeto_id
),
ultimo_status AS (
  -- o status publicado mais recente até hoje
  SELECT projeto_id, farol
  FROM (
    SELECT projeto_id, farol,
           row_number() OVER (PARTITION BY projeto_id ORDER BY data_status DESC) AS n
    FROM status_semanal
    WHERE data_status <= DATE'2026-10-16'
  )
  WHERE n = 1
),
kpis AS (
  SELECT
    p.*,
    datediff(p.data_fim_baseline, p.data_inicio)                              AS duracao_baseline_dias,
    round(p.orcamento_custo * try_divide(t.horas_planejadas, t.horas_totais), 2) AS pv,
    round(p.orcamento_custo * try_divide(t.horas_agregadas, t.horas_totais), 2)  AS ev,
    coalesce(c.ac, 0)                                                         AS ac,
    s.farol                                                                   AS farol_do_gerente
  FROM projetos p
  LEFT JOIN tarefas_hoje t  ON t.projeto_id = p.projeto_id
  LEFT JOIN custo_hoje c    ON c.projeto_id = p.projeto_id
  LEFT JOIN ultimo_status s ON s.projeto_id = p.projeto_id
),
indices AS (
  SELECT
    *,
    round(try_divide(ev, pv), 4) AS spi,
    round(try_divide(ev, ac), 4) AS cpi
  FROM kpis
),
projecao AS (
  SELECT
    *,
    round(try_divide(orcamento_custo, cpi), 2)          AS eac,
    try_divide(duracao_baseline_dias, spi)              AS duracao_projetada_dias
  FROM indices
)
SELECT
  projeto_id,
  projeto_id                                            AS projeto,   -- o código (PRJ-000), como pede o contrato da gold
  nome_projeto                                          AS nome,
  cliente,
  segmento,
  tipo_projeto,
  ferramenta,
  gerente_projeto,
  valor_contrato,
  orcamento_custo                                       AS orcamento,
  data_inicio,
  data_fim_baseline,
  duracao_baseline_dias,
  status,
  pv,
  ev,
  ac,
  spi,
  cpi,
  eac,
  round(greatest(eac - orcamento_custo, 0), 2)          AS estouro_previsto,
  round(try_divide(valor_contrato - eac, valor_contrato), 4) AS margem_projetada,
  CAST(round(duracao_projetada_dias - duracao_baseline_dias) AS INT) AS atraso_projetado_dias,
  date_add(data_inicio, CAST(round(duracao_projetada_dias) AS INT))  AS termino_projetado,
  CASE
    WHEN status <> 'em_andamento'  THEN 'concluído'
    WHEN spi < 0.8 OR cpi < 0.8    THEN 'crítico'
    WHEN spi < 0.9 OR cpi < 0.9    THEN 'atenção'
    ELSE 'ok'
  END                                                   AS situacao,
  farol_do_gerente,
  CASE
    WHEN spi >= 0.95 THEN 'verde'
    WHEN spi >= 0.90 THEN 'amarelo'
    ELSE 'vermelho'
  END                                                   AS farol_calculado,
  coalesce(status = 'em_andamento' AND farol_do_gerente = 'verde' AND spi < 0.9, false) AS melancia
FROM projecao;

CREATE OR REFRESH MATERIALIZED VIEW lakehouse_vertice.gold.utilizacao_pessoa_semana
COMMENT 'Timesheet por pessoa, projeto e semana (sexta-feira): nome, papel e senioridade da pessoa, horas disponíveis, apontadas e ociosas, utilização (apontadas ÷ disponíveis), custo ocioso (horas ociosas × custo por hora) e o SPI do projeto naquela semana. Responde se há gente parada enquanto outro projeto pede gente.'
AS
SELECT
  a.colaborador_id,
  c.nome,
  c.papel,
  c.senioridade,
  a.projeto_id,
  a.semana,
  a.horas_disponiveis,
  a.horas_apontadas,
  greatest(a.horas_disponiveis - a.horas_apontadas, 0)                    AS horas_ociosas,
  round(try_divide(a.horas_apontadas, a.horas_disponiveis), 4)            AS utilizacao,
  round(greatest(a.horas_disponiveis - a.horas_apontadas, 0) * c.custo_hora, 2) AS custo_ocioso,
  f.spi                                                                   AS spi_do_projeto
FROM apontamentos a
JOIN colaboradores c
  ON c.colaborador_id = a.colaborador_id
LEFT JOIN lakehouse_vertice.gold.fato_projeto_semana f
  ON f.projeto_id = a.projeto_id AND f.semana = a.semana;
