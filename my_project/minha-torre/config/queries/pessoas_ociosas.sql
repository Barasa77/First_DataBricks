-- Pessoas paradas: utilização < 20% nas últimas 12 semanas (31/07 a 16/10/2026),
-- com horas paradas e custo ocioso MÉDIOS por semana.
WITH janela AS (
  SELECT
    u.colaborador_id,
    u.nome,
    u.papel,
    u.senioridade,
    u.projeto_id,
    count(DISTINCT u.semana)                                     AS semanas,
    try_divide(SUM(u.horas_apontadas), SUM(u.horas_disponiveis)) AS utilizacao,
    SUM(u.horas_ociosas)                                         AS horas_ociosas,
    SUM(u.custo_ocioso)                                          AS custo_ocioso
  FROM lakehouse_vertice.gold.utilizacao_pessoa_semana u
  WHERE u.semana > DATE'2026-07-24' AND u.semana <= DATE'2026-10-16'
  GROUP BY u.colaborador_id, u.nome, u.papel, u.senioridade, u.projeto_id
)
SELECT
  j.colaborador_id,
  j.nome,
  j.papel,
  j.senioridade,
  j.projeto_id,
  j.utilizacao,
  j.horas_ociosas / j.semanas  AS horas_paradas_semana,
  j.custo_ocioso / j.semanas   AS custo_ocioso_semana,
  c.custo_hora
FROM janela j
JOIN lakehouse_vertice.silver.colaboradores c ON c.colaborador_id = j.colaborador_id
WHERE j.utilizacao < 0.2
ORDER BY custo_ocioso_semana DESC
