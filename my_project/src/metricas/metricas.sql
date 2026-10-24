-- Métricas governadas: a fórmula de cada KPI num lugar só.
-- O dashboard, o Genie e o app leem daqui, e o SPI da carteira é sempre SUM(ev) / SUM(pv).
-- ATENÇÃO: a sql_task corta o arquivo em todo ponto e vírgula, inclusive dentro do YAML abaixo.
-- Nunca escreva ponto e vírgula no YAML (nem num comment). Teste com:
--   python scripts/run_sql.py src/metricas/metricas.sql --profile <perfil>

CREATE OR REPLACE VIEW lakehouse_vertice.gold.mv_projetos
WITH METRICS
LANGUAGE YAML
AS $$
version: 1.1
comment: "KPIs da carteira de projetos em andamento da Vértice na fotografia de hoje (16/10/2026). Razões como SPI e CPI são sempre soma sobre soma, nunca média de razões."
source: lakehouse_vertice.gold.projeto_situacao_atual
filter: status = 'em_andamento'

dimensions:
  - name: projeto_id
    expr: projeto_id
    comment: "Código do projeto, no formato PRJ-000"
    synonyms: ["código do projeto", "id do projeto"]
  - name: projeto
    expr: projeto
    comment: "Código do projeto (PRJ-000), o mesmo valor de projeto_id"
    synonyms: ["projeto", "código"]
  - name: cliente
    expr: cliente
    synonyms: ["empresa cliente", "conta"]
  - name: segmento
    expr: segmento
    comment: "Segmento do cliente: varejo, financeiro, saude, logistica ou industria"
    synonyms: ["setor", "vertical", "mercado"]
  - name: ferramenta
    expr: ferramenta
    comment: "Onde o gerente controla o cronograma: excel, clickup ou msproject"
    synonyms: ["ferramenta de gestão", "sistema de cronograma"]
  - name: situacao
    expr: situacao
    comment: "ok, atenção (SPI ou CPI abaixo de 0,9) ou crítico (SPI ou CPI abaixo de 0,8)"
    synonyms: ["status de risco", "risco", "situação"]
  - name: farol_do_gerente
    expr: farol_do_gerente
    comment: "Farol que o gerente publicou no último status semanal: verde, amarelo ou vermelho"
    synonyms: ["farol declarado", "farol do status", "semáforo do gerente"]
  - name: farol_calculado
    expr: farol_calculado
    comment: "Farol pela regra do manual a partir do SPI: verde com SPI de 0,95 ou mais, amarelo de 0,90 ou mais, vermelho abaixo"
    synonyms: ["farol pelo número", "farol real", "farol pelo SPI"]
  - name: gerente_projeto
    expr: gerente_projeto
    synonyms: ["gerente", "gestor do projeto", "GP"]

measures:
  - name: projetos
    expr: COUNT(projeto_id)
    comment: "Quantidade de projetos em andamento"
    synonyms: ["quantidade de projetos", "número de projetos", "total de projetos"]
  - name: carteira
    expr: SUM(valor_contrato)
    comment: "Soma do valor dos contratos, em reais"
    synonyms: ["valor da carteira", "valor dos contratos", "receita contratada"]
  - name: spi
    expr: SUM(ev) / SUM(pv)
    comment: "Índice de desempenho de prazo (EV dividido por PV). Abaixo de 1 é atraso"
    synonyms: ["índice de prazo", "desempenho de prazo", "schedule performance index"]
  - name: cpi
    expr: SUM(ev) / SUM(ac)
    comment: "Índice de desempenho de custo (EV dividido por AC). Abaixo de 1 é estouro de custo"
    synonyms: ["índice de custo", "desempenho de custo", "cost performance index"]
  - name: eac
    expr: SUM(eac)
    comment: "Custo estimado no término (orçamento dividido pelo CPI), em reais"
    synonyms: ["estimativa no término", "custo final previsto", "estimate at completion"]
  - name: estouro_previsto
    expr: SUM(estouro_previsto)
    comment: "Quanto o EAC passa do orçamento, só quando positivo, em reais"
    synonyms: ["estouro de orçamento", "custo do atraso", "quanto vai custar", "prejuízo previsto"]
  - name: margem_projetada
    expr: (SUM(valor_contrato) - SUM(eac)) / SUM(valor_contrato)
    comment: "Margem projetada da carteira, de 0 a 1: (contrato menos EAC) dividido pelo contrato"
    synonyms: ["margem", "margem prevista", "lucratividade projetada"]
  - name: atraso_projetado_medio_dias
    expr: AVG(atraso_projetado_dias)
    comment: "Atraso projetado médio em dias (duração do baseline dividida pelo SPI, menos a duração do baseline)"
    synonyms: ["atraso médio", "dias de atraso", "atraso previsto"]
  - name: projetos_em_risco
    expr: COUNT(projeto_id) FILTER (WHERE situacao IN ('atenção', 'crítico'))
    comment: "Projetos em atenção ou críticos"
    synonyms: ["projetos atrasados", "projetos com problema", "em risco"]
  - name: projetos_criticos
    expr: COUNT(projeto_id) FILTER (WHERE situacao = 'crítico')
    comment: "Projetos com SPI ou CPI abaixo de 0,8"
    synonyms: ["críticos", "projetos em situação crítica"]
  - name: projetos_melancia
    expr: COUNT(projeto_id) FILTER (WHERE melancia)
    comment: "Melancias: farol do gerente verde e SPI abaixo de 0,9 (verde por fora, vermelho por dentro)"
    synonyms: ["melancias", "farol enganoso", "verde mas atrasado"]
$$
