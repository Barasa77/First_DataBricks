-- O texto livre do status semanal vira coluna: causa do bloqueio, quem destrava e dias de impacto.
-- Cada ferramenta onde ela é a certa:
--   regra         status vazio e semana sem bloqueio (custo zero, resposta exata)
--   ia            texto com bloqueio dos últimos 90 dias (ai_classify + ai_extract, versão 2.0)
--   palavra_chave histórico antigo, onde a resposta não muda decisão
-- A tabela acumula: o MERGE só processa status que ainda não estão nela.
-- Atenção: a sql_task corta o arquivo em todo ponto e vírgula, então nada de ponto e vírgula em texto ou comentário.

CREATE TABLE IF NOT EXISTS lakehouse_vertice.gold.status_estruturado (
  projeto_id       STRING    COMMENT 'Projeto (PRJ-xxx)',
  data_status      DATE      COMMENT 'Sexta-feira do status publicado pelo gerente',
  farol            STRING    COMMENT 'Farol do gerente naquela semana: verde, amarelo ou vermelho',
  causa_bloqueio   STRING    COMMENT 'Causa do bloqueio: change_freeze, falta_sre, dependencia_fornecedor, rotatividade, mudanca_escopo, bug_retrabalho, aprovacao_cliente, sem_bloqueio ou nao_reportado (status vazio)',
  bloqueio         STRING    COMMENT 'O bloqueio em uma frase (extraído pela IA, só nos últimos 90 dias)',
  quem_destrava    STRING    COMMENT 'Quem pode destravar o bloqueio (extraído pela IA, só nos últimos 90 dias)',
  dias_impacto     DOUBLE    COMMENT 'Dias de impacto no cronograma declarados no texto (1 semana = 7)',
  metodo           STRING    COMMENT 'Como a linha foi classificada: regra, ia ou palavra_chave',
  texto_status     STRING    COMMENT 'Texto livre original do status semanal',
  _classificado_em TIMESTAMP COMMENT 'Quando a linha foi classificada (a tabela acumula, nada é reprocessado)'
)
COMMENT 'Status semanal estruturado: a causa de cada bloqueio tirada do texto livre do gerente, uma linha por projeto e sexta-feira. IA (ai_classify + ai_extract) só nos status com bloqueio dos últimos 90 dias, regra para status vazio ou sem bloqueio, palavra-chave para o histórico. Incremental: cada execução só classifica os status novos.';

MERGE INTO lakehouse_vertice.gold.status_estruturado AS destino
USING (
  WITH novos AS (
    -- só o que ainda não foi classificado
    SELECT
      s.projeto_id,
      s.data_status,
      s.farol,
      s.texto_status,
      s.status_vazio,
      lower(coalesce(s.texto_status, '')) AS texto,
      -- o trecho do bloqueio, para a IA ler só o que interessa
      coalesce(nullif(regexp_extract(s.texto_status, 'Bloqueios: (.*)$', 1), ''), s.texto_status) AS trecho_bloqueio
    FROM lakehouse_vertice.silver.status_semanal s
    LEFT ANTI JOIN lakehouse_vertice.gold.status_estruturado e
      ON e.projeto_id = s.projeto_id AND e.data_status = s.data_status
  ),
  com_metodo AS (
    SELECT
      *,
      CASE
        WHEN status_vazio
          OR texto LIKE '%bloqueios: nenhum%'
          OR texto LIKE '%sem bloqueios%'
          OR texto LIKE '%nada relevante%'      THEN 'regra'
        WHEN data_status >= DATE'2026-07-18'     THEN 'ia'
        ELSE 'palavra_chave'
      END AS metodo,
      -- 'impacto estimado de N dias' ou 'impacto estimado: 1 semana'
      CASE
        WHEN texto RLIKE 'impacto estimado de [0-9]+ dias'
          THEN CAST(regexp_extract(texto, 'impacto estimado de ([0-9]+) dias', 1) AS DOUBLE)
        WHEN texto LIKE '%impacto estimado: 1 semana%' THEN 7.0
      END AS dias_impacto_regex
    FROM novos
  ),
  por_regra AS (
    SELECT
      projeto_id, data_status, farol,
      CASE WHEN status_vazio THEN 'nao_reportado' ELSE 'sem_bloqueio' END AS causa_bloqueio,
      CAST(NULL AS STRING) AS bloqueio,
      CAST(NULL AS STRING) AS quem_destrava,
      dias_impacto_regex   AS dias_impacto,
      metodo, texto_status
    FROM com_metodo
    WHERE metodo = 'regra'
  ),
  ia_bruta AS (
    -- a IA só roda aqui: ~160 textos
    SELECT
      *,
      ai_classify(
        trecho_bloqueio,
        '["change_freeze","falta_sre","dependencia_fornecedor","rotatividade","mudanca_escopo","bug_retrabalho","aprovacao_cliente","sem_bloqueio"]',
        map('version', '2.0')
      ) AS classificacao,
      ai_extract(
        trecho_bloqueio,
        '{"bloqueio":{"type":"string"},"quem_destrava":{"type":"string"},"dias_impacto":{"type":"number","description":"dias de impacto no cronograma, 1 semana = 7"}}',
        map('version', '2.0')
      ) AS extracao
    FROM com_metodo
    WHERE metodo = 'ia'
  ),
  por_ia AS (
    SELECT
      projeto_id, data_status, farol,
      classificacao:response[0]::STRING                                     AS causa_bloqueio,
      extracao:response:bloqueio::STRING                                    AS bloqueio,
      extracao:response:quem_destrava::STRING                               AS quem_destrava,
      coalesce(extracao:response:dias_impacto::DOUBLE, dias_impacto_regex)  AS dias_impacto,
      metodo, texto_status
    FROM ia_bruta
  ),
  por_palavra_chave AS (
    SELECT
      projeto_id, data_status, farol,
      CASE
        WHEN texto RLIKE 'freeze|congelamento|janela de deploy'                   THEN 'change_freeze'
        WHEN texto RLIKE 'sre|infraestrutura|ambiente de homologação'             THEN 'falta_sre'
        WHEN texto RLIKE 'forge|consultoria|fornecedor'                           THEN 'dependencia_fornecedor'
        WHEN texto RLIKE 'saída de|rotatividade|onboarding'                       THEN 'rotatividade'
        WHEN texto RLIKE 'escopo|change request|regra de negócio'                 THEN 'mudanca_escopo'
        WHEN texto RLIKE 'bugs|regressão|refazendo'                               THEN 'bug_retrabalho'
        WHEN texto RLIKE 'aprovação do cliente|homologação do cliente'            THEN 'aprovacao_cliente'
        ELSE 'sem_bloqueio'
      END AS causa_bloqueio,
      CAST(NULL AS STRING) AS bloqueio,
      CAST(NULL AS STRING) AS quem_destrava,
      dias_impacto_regex   AS dias_impacto,
      metodo, texto_status
    FROM com_metodo
    WHERE metodo = 'palavra_chave'
  )
  SELECT *, current_timestamp() AS _classificado_em FROM por_regra
  UNION ALL
  SELECT *, current_timestamp() FROM por_ia
  UNION ALL
  SELECT *, current_timestamp() FROM por_palavra_chave
) AS origem
ON destino.projeto_id = origem.projeto_id AND destino.data_status = origem.data_status
WHEN NOT MATCHED THEN INSERT *;

-- Leitura: quantos status por método e causa
SELECT metodo, causa_bloqueio, count(*) AS status
FROM lakehouse_vertice.gold.status_estruturado
GROUP BY metodo, causa_bloqueio
ORDER BY metodo, status DESC;
