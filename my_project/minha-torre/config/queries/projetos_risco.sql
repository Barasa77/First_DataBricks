-- Projetos em andamento, do pior para o melhor, com a causa que o gerente escreve no status.
WITH causas_90d AS (
  -- bloqueios declarados nos últimos 90 dias (até 16/10/2026)
  SELECT projeto_id, causa_bloqueio, count(*) AS semanas, SUM(coalesce(dias_impacto, 0)) AS dias_impacto
  FROM lakehouse_vertice.gold.status_estruturado
  WHERE data_status >= DATE'2026-07-18'
    AND causa_bloqueio NOT IN ('sem_bloqueio', 'nao_reportado')
  GROUP BY projeto_id, causa_bloqueio
),
por_projeto AS (
  SELECT
    projeto_id,
    max_by(causa_bloqueio, semanas)                                         AS causa_principal,
    max(semanas)                                                            AS semanas_causa_principal,
    coalesce(SUM(CASE WHEN causa_bloqueio = 'falta_sre' THEN dias_impacto END), 0)    AS dias_falta_sre,
    coalesce(SUM(CASE WHEN causa_bloqueio = 'rotatividade' THEN dias_impacto END), 0) AS dias_rotatividade
  FROM causas_90d
  GROUP BY projeto_id
)
SELECT
  p.projeto_id,
  p.nome AS nome_projeto,
  p.cliente,
  p.situacao,
  p.spi,
  p.cpi,
  p.estouro_previsto,
  p.atraso_projetado_dias,
  p.farol_do_gerente,
  p.farol_calculado,
  p.melancia,
  c.causa_principal,
  coalesce(c.semanas_causa_principal, 0) AS semanas_causa_principal,
  coalesce(c.dias_falta_sre, 0)          AS dias_falta_sre,
  coalesce(c.dias_rotatividade, 0)       AS dias_rotatividade
FROM lakehouse_vertice.gold.projeto_situacao_atual p
LEFT JOIN por_projeto c ON c.projeto_id = p.projeto_id
WHERE p.status = 'em_andamento'
ORDER BY
  CASE p.situacao WHEN 'crítico' THEN 1 WHEN 'atenção' THEN 2 ELSE 3 END,
  least(p.spi, p.cpi),
  p.estouro_previsto DESC
