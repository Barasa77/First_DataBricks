-- Conferência da bronze antes da silver.
-- Cada uma das 9 tabelas tem que ter exatamente as linhas geradas com seed 42.
-- bronze.feriados fica de fora: cresce a cada execução da ingestão.

CREATE OR REPLACE TEMPORARY VIEW conferencia AS
WITH esperado AS (
  SELECT * FROM VALUES
    ('projetos',            60),
    ('status_semanal',      3911),
    ('excel_tarefas',       1663),
    ('clickup_tarefas',     2119),
    ('msproject_tarefas',   1260),
    ('colaboradores',       523),
    ('apontamentos',        30883),
    ('custos',              23640),
    ('entregas_fornecedor', 640)
  AS t(tabela, esperado)
),
obtido AS (
  SELECT 'projetos'            AS tabela, count(*) AS obtido FROM lakehouse_vertice.bronze.projetos
  UNION ALL SELECT 'status_semanal',      count(*) FROM lakehouse_vertice.bronze.status_semanal
  UNION ALL SELECT 'excel_tarefas',       count(*) FROM lakehouse_vertice.bronze.excel_tarefas
  UNION ALL SELECT 'clickup_tarefas',     count(*) FROM lakehouse_vertice.bronze.clickup_tarefas
  UNION ALL SELECT 'msproject_tarefas',   count(*) FROM lakehouse_vertice.bronze.msproject_tarefas
  UNION ALL SELECT 'colaboradores',       count(*) FROM lakehouse_vertice.bronze.colaboradores
  UNION ALL SELECT 'apontamentos',        count(*) FROM lakehouse_vertice.bronze.apontamentos
  UNION ALL SELECT 'custos',              count(*) FROM lakehouse_vertice.bronze.custos
  UNION ALL SELECT 'entregas_fornecedor', count(*) FROM lakehouse_vertice.bronze.entregas_fornecedor
)
SELECT e.tabela, e.esperado, o.obtido, e.esperado = o.obtido AS ok
FROM esperado e
JOIN obtido o USING (tabela);

-- Uma linha por tabela: esperado × obtido
SELECT * FROM conferencia ORDER BY tabela;

-- Se alguma tabela divergir, a tarefa falha e o medalhão não roda
SELECT CASE
  WHEN count_if(NOT ok) > 0 THEN raise_error(concat(
    'Bronze divergente: ',
    array_join(collect_list(CASE WHEN NOT ok THEN concat(tabela, ' (esperado ', esperado, ', obtido ', obtido, ')') END), ', '),
    '. Olhe a saída da tarefa ingestao_data_lake.'))
  ELSE 'bronze conferida: 9 tabelas ok'
END AS resultado
FROM conferencia;
