-- Cadastro do PMO: 60 projetos. É o de-para da integração:
-- (ferramenta, codigo_ferramenta) diz onde cada projeto é controlado.

CREATE OR REFRESH MATERIALIZED VIEW projetos (
  CONSTRAINT data_inicio_valida EXPECT (data_inicio IS NOT NULL) ON VIOLATION FAIL UPDATE,
  CONSTRAINT ferramenta_conhecida EXPECT (ferramenta IN ('excel', 'clickup', 'msproject')) ON VIOLATION FAIL UPDATE
)
COMMENT 'Cadastro dos 60 projetos da Vértice (um por linha), com cliente, segmento, valor do contrato, orçamento de custo, datas e a ferramenta onde o gerente controla o cronograma (excel, clickup ou msproject). codigo_ferramenta é o de-para para as tarefas: nome do arquivo (Excel/MS Project) ou list_id (ClickUp).'
AS
SELECT
  projeto_id,
  nome_projeto,
  cliente,
  segmento,
  tipo_projeto,
  -- 8 grafias ('MS Project', 'Project', 'Planilha', 'Clickup'...) viram 3 valores
  CASE
    WHEN lower(ferramenta) LIKE '%click%'                                     THEN 'clickup'
    WHEN lower(ferramenta) LIKE '%project%'                                   THEN 'msproject'
    WHEN lower(ferramenta) LIKE '%excel%' OR lower(ferramenta) LIKE '%planilha%' THEN 'excel'
  END                                                    AS ferramenta,
  ferramenta                                             AS ferramenta_como_veio,
  nullif(trim(codigo_ferramenta), '')                    AS codigo_ferramenta,
  CAST(valor_contrato AS DECIMAL(15, 2))                 AS valor_contrato,
  CAST(orcamento_custo AS DECIMAL(15, 2))                AS orcamento_custo,
  -- data em dois formatos: yyyy-MM-dd e dd/MM/yyyy
  coalesce(try_to_date(data_inicio, 'yyyy-MM-dd'), try_to_date(data_inicio, 'dd/MM/yyyy'))             AS data_inicio,
  coalesce(try_to_date(data_fim_baseline, 'yyyy-MM-dd'), try_to_date(data_fim_baseline, 'dd/MM/yyyy')) AS data_fim_baseline,
  status,
  gerente_projeto
FROM lakehouse_vertice.bronze.projetos;
