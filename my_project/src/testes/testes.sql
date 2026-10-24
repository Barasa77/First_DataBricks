-- Testes de qualidade da silver e da gold. Cada teste devolve 'ok' ou para o job com raise_error.

-- 1. Os 60 projetos têm cronograma na silver.tarefas
SELECT CASE WHEN count(DISTINCT projeto_id) <> 60
  THEN raise_error(format_string('Teste 1: só %d projetos têm tarefas na silver.tarefas (esperado 60)', count(DISTINCT projeto_id)))
  ELSE 'teste 1 ok: 60 projetos com cronograma' END AS teste_1
FROM lakehouse_vertice.silver.tarefas;

-- 2. Cada projeto veio de UMA ferramenta, a do cadastro do PMO
SELECT CASE WHEN count(*) > 0
  THEN raise_error(concat('Teste 2: projetos com ferramenta diferente do cadastro ou mais de uma: ', array_join(collect_list(projeto_id), ', ')))
  ELSE 'teste 2 ok: uma ferramenta por projeto, a do cadastro' END AS teste_2
FROM (
  SELECT t.projeto_id
  FROM lakehouse_vertice.silver.tarefas t
  JOIN lakehouse_vertice.silver.projetos p ON p.projeto_id = t.projeto_id
  GROUP BY t.projeto_id, p.ferramenta
  HAVING count(DISTINCT t.ferramenta) <> 1 OR max(t.ferramenta) <> p.ferramenta
);

-- 3. As horas do Excel na silver = a soma das linhas de TOTAL das planilhas
SELECT CASE WHEN abs(silver - total) > 0.01
  THEN raise_error(format_string('Teste 3: horas do Excel na silver (%.2f) diferem da soma dos TOTAIS (%.2f)', silver, total))
  ELSE 'teste 3 ok: horas do Excel batem com as linhas de TOTAL' END AS teste_3
FROM (
  SELECT
    (SELECT sum(horas) FROM lakehouse_vertice.silver.tarefas WHERE ferramenta = 'excel') AS silver,
    (SELECT sum(CAST(replace(horas_previstas, 'h', '') AS DOUBLE))
       FROM lakehouse_vertice.bronze.excel_tarefas WHERE tarefa = 'TOTAL')              AS total
);

-- 4. Uma linha por pessoa na silver
SELECT CASE WHEN count(*) <> count(DISTINCT colaborador_id)
  THEN raise_error(format_string('Teste 4: %d linhas para %d pessoas em silver.colaboradores', count(*), count(DISTINCT colaborador_id)))
  ELSE 'teste 4 ok: uma linha por pessoa' END AS teste_4
FROM lakehouse_vertice.silver.colaboradores;

-- 5. A CodeForge virou um fornecedor só
SELECT CASE WHEN count(DISTINCT fornecedor) <> 1
  THEN raise_error(concat('Teste 5: a CodeForge aparece como ', array_join(collect_set(fornecedor), ' / ')))
  ELSE 'teste 5 ok: CodeForge normalizada' END AS teste_5
FROM lakehouse_vertice.silver.entregas_fornecedor
WHERE replace(lower(fornecedor_como_veio), ' ', '') LIKE '%codeforge%';

-- 6. A limpeza não mudou o custo total (bronze com replace = silver)
SELECT CASE WHEN bronze <> silver
  THEN raise_error(format_string('Teste 6: custo total da bronze (%s) diferente da silver (%s)', bronze, silver))
  ELSE 'teste 6 ok: custo total preservado' END AS teste_6
FROM (
  SELECT
    (SELECT sum(CAST(replace(valor, ',', '.') AS DECIMAL(15, 2))) FROM lakehouse_vertice.bronze.custos) AS bronze,
    (SELECT sum(valor) FROM lakehouse_vertice.silver.custos)                                           AS silver
);

-- 7. Os 60 projetos têm fotografia de hoje
SELECT CASE WHEN count(*) <> 60 OR count(DISTINCT projeto_id) <> 60
  THEN raise_error(format_string('Teste 7: projeto_situacao_atual tem %d linhas (esperado 60, uma por projeto)', count(*)))
  ELSE 'teste 7 ok: 60 projetos na fotografia de hoje' END AS teste_7
FROM lakehouse_vertice.gold.projeto_situacao_atual;

-- 8. Todo projeto em andamento tem SPI e CPI
SELECT CASE WHEN count(*) > 0
  THEN raise_error(concat('Teste 8: projetos em andamento sem SPI ou CPI: ', array_join(collect_list(projeto_id), ', ')))
  ELSE 'teste 8 ok: SPI e CPI em todos os projetos em andamento' END AS teste_8
FROM lakehouse_vertice.gold.projeto_situacao_atual
WHERE status = 'em_andamento' AND (spi IS NULL OR cpi IS NULL);

-- 9. O EV de hoje do status semanal bate com o das ferramentas (diferença < 1% na carteira)
SELECT CASE WHEN abs(ev_status - ev_ferramentas) / ev_ferramentas >= 0.01
  THEN raise_error(format_string('Teste 9: EV de hoje pelo status (%.2f) difere do EV pelas ferramentas (%.2f) em %.2f%%',
                                 ev_status, ev_ferramentas, 100 * abs(ev_status - ev_ferramentas) / ev_ferramentas))
  ELSE 'teste 9 ok: EV do status semanal = EV das ferramentas' END AS teste_9
FROM (
  SELECT
    (SELECT CAST(sum(ev) AS DOUBLE) FROM lakehouse_vertice.gold.fato_projeto_semana WHERE semana = DATE'2026-10-16') AS ev_status,
    (SELECT CAST(sum(ev) AS DOUBLE) FROM lakehouse_vertice.gold.projeto_situacao_atual)                              AS ev_ferramentas
);

-- 10. AC de hoje no fato = soma dos lançamentos até hoje
SELECT CASE WHEN ac_fato <> ac_custos
  THEN raise_error(format_string('Teste 10: AC de hoje no fato (%s) diferente da soma dos lançamentos até hoje (%s)', ac_fato, ac_custos))
  ELSE 'teste 10 ok: AC de hoje = lançamentos até hoje' END AS teste_10
FROM (
  SELECT
    (SELECT sum(ac) FROM lakehouse_vertice.gold.fato_projeto_semana WHERE semana = DATE'2026-10-16')   AS ac_fato,
    (SELECT sum(valor) FROM lakehouse_vertice.silver.custos WHERE data <= DATE'2026-10-16')            AS ac_custos
);
