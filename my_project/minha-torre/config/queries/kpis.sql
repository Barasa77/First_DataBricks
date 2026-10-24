-- KPIs da carteira em andamento, na fotografia de hoje (16/10/2026).
-- Nada do score aqui: o "alto risco em 30 dias" vem da rota /api/score-estouro.
SELECT
  count(*)                                       AS projetos_em_andamento,
  count_if(situacao IN ('atenção', 'crítico'))   AS em_risco,
  count_if(situacao = 'crítico')                 AS criticos,
  count_if(melancia)                             AS melancias,
  SUM(estouro_previsto)                          AS estouro_previsto,
  SUM(valor_contrato)                            AS carteira
FROM lakehouse_vertice.gold.projeto_situacao_atual
WHERE status = 'em_andamento'
