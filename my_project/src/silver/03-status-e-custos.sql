-- Status semanal dos gerentes e lançamentos de custo real.

CREATE OR REFRESH MATERIALIZED VIEW status_semanal (
  CONSTRAINT farol_conhecido EXPECT (farol IN ('verde', 'amarelo', 'vermelho')) ON VIOLATION FAIL UPDATE
)
COMMENT 'Status que o gerente publica toda sexta, um por projeto e semana: % concluído declarado, farol do gerente (verde, amarelo, vermelho) e o texto livre com entregas e bloqueios. status_vazio marca textos sem conteúdo (vazio, N/A, ver ata da reunião), que são mantidos.'
AS
SELECT
  projeto_id,
  to_date(data_status)                 AS data_status,
  gerente,
  -- 'Verde', 'VERDE' → 'verde'
  lower(trim(farol))                   AS farol,
  CAST(pct_concluido AS INT)           AS pct_concluido,
  texto_status,
  -- texto sem conteúdo: sinaliza, não descarta
  coalesce(trim(texto_status), '') IN ('', 'N/A', 'ver ata da reunião') AS status_vazio
FROM lakehouse_vertice.bronze.status_semanal;

CREATE OR REFRESH MATERIALIZED VIEW custos
COMMENT 'Lançamentos de custo real por projeto (pessoal, consultoria, cloud, licenças, despesas), em reais. Estornos vêm como valor negativo e ficam (o custo é líquido), marcados em estorno. semana é a sexta-feira da semana do lançamento.'
AS
SELECT
  lancamento_id,
  projeto_id,
  to_date(data)                                        AS data,
  -- sexta-feira da semana (a semana começa na segunda)
  date_add(to_date(date_trunc('WEEK', to_date(data))), 4) AS semana,
  categoria,
  descricao,
  -- 671 valores com vírgula decimal: troca ANTES do CAST (try_cast jogaria R$ 5,4 mi fora)
  CAST(replace(valor, ',', '.') AS DECIMAL(15, 2))     AS valor,
  CAST(replace(valor, ',', '.') AS DECIMAL(15, 2)) < 0 AS estorno,
  centro_custo
FROM lakehouse_vertice.bronze.custos;
