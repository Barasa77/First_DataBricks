#!/usr/bin/env python3
"""Gera resources/dashboard-portfolio.lvdash.json (AI/BI, GRID_V1).

O dashboard é código: a mudança vai aqui, o script gera o JSON e o bundle faz o
deploy. Não edite o dashboard no workspace (o próximo deploy recusa).

As queries da gold usam o nome de tabela PURO: quem completa catálogo e schema
é o recurso do bundle (dataset_catalog / dataset_schema). A silver vai com o
nome completo.

Uso:
  python scripts/gerar_dashboard.py
"""
import json
from pathlib import Path

SAIDA = Path(__file__).resolve().parent.parent / "resources" / "dashboard-portfolio.lvdash.json"

# Cores da Jornada e cores semânticas da situação
AZUL, CIANO, FUNDO_ESCURO = "#0059DB", "#22C2F4", "#14141A"
CRITICO, ATENCAO, OK = "#FF5F46", "#F6C344", "#22C2F4"
CORES_SITUACAO = [
    {"value": "crítico", "color": CRITICO},
    {"value": "atenção", "color": ATENCAO},
    {"value": "ok", "color": OK},
]

# Formatos
REAIS = {"type": "number-currency", "currencyCode": "BRL", "abbreviation": "compact",
         "decimalPlaces": {"type": "max", "places": 2}}
INDICE = {"type": "number", "decimalPlaces": {"type": "exact", "places": 2}}
PERCENTUAL = {"type": "number-percent", "decimalPlaces": {"type": "max", "places": 1}}
INTEIRO = {"type": "number", "decimalPlaces": {"type": "max", "places": 0}}
HORAS = {"type": "number", "decimalPlaces": {"type": "max", "places": 1}}


# ---------------------------------------------------------------------------
# Datasets: toda a lógica de negócio fica no SQL. Razão é SUM/SUM, nunca AVG de razão.
# ---------------------------------------------------------------------------
DATASETS = {
    "ds_kpis": ("KPIs da carteira em andamento", """
SELECT
  SUM(valor_contrato)                                  AS carteira,
  try_divide(SUM(ev), SUM(pv))                         AS spi,
  try_divide(SUM(ev), SUM(ac))                         AS cpi,
  SUM(estouro_previsto)                                AS estouro_previsto,
  count_if(situacao IN ('atenção', 'crítico'))         AS em_risco,
  count_if(situacao = 'crítico')                       AS criticos,
  count_if(melancia)                                   AS melancias
FROM projeto_situacao_atual
WHERE status = 'em_andamento'
"""),
    "ds_projetos": ("Projetos em andamento", """
SELECT
  projeto_id,
  nome,
  cliente,
  ferramenta,
  gerente_projeto,
  situacao,
  spi,
  cpi,
  orcamento,
  eac,
  estouro_previsto,
  atraso_projetado_dias,
  termino_projetado,
  farol_do_gerente,
  farol_calculado,
  CASE WHEN melancia THEN 'melancia' ELSE '' END AS melancia
FROM projeto_situacao_atual
WHERE status = 'em_andamento'
ORDER BY estouro_previsto DESC, spi
"""),
    "ds_carteira_semanal": ("SPI e CPI semanais da carteira", """
SELECT
  semana,
  try_divide(SUM(ev), SUM(pv)) AS spi,
  try_divide(SUM(ev), SUM(ac)) AS cpi
FROM fato_projeto_semana
WHERE semana >= DATE'2025-03-07'
GROUP BY semana
ORDER BY semana
"""),
    "ds_custo_ocioso": ("Top 15 custo da hora parada (12 semanas)", """
SELECT
  concat(colaborador_id, ' · ', nome, ' (', papel, ')') AS pessoa,
  SUM(custo_ocioso)                                      AS custo_ocioso,
  SUM(horas_ociosas)                                     AS horas_ociosas,
  try_divide(SUM(horas_apontadas), SUM(horas_disponiveis)) AS utilizacao
FROM utilizacao_pessoa_semana
WHERE semana > DATE'2026-07-24' AND semana <= DATE'2026-10-16'
GROUP BY colaborador_id, nome, papel
ORDER BY custo_ocioso DESC
LIMIT 15
"""),
    "ds_utilizacao": ("Utilização por pessoa e projeto (12 semanas)", """
SELECT
  colaborador_id,
  nome,
  papel,
  senioridade,
  projeto_id,
  SUM(horas_disponiveis)                                   AS horas_disponiveis,
  SUM(horas_apontadas)                                     AS horas_apontadas,
  SUM(horas_ociosas)                                       AS horas_ociosas,
  try_divide(SUM(horas_apontadas), SUM(horas_disponiveis)) AS utilizacao,
  SUM(custo_ocioso)                                        AS custo_ocioso
FROM utilizacao_pessoa_semana
WHERE semana > DATE'2026-07-24' AND semana <= DATE'2026-10-16'
GROUP BY colaborador_id, nome, papel, senioridade, projeto_id
ORDER BY utilizacao, custo_ocioso DESC
"""),
    "ds_causas": ("Causas de bloqueio por projeto (90 dias)", """
SELECT
  projeto_id,
  causa_bloqueio,
  COUNT(*)                          AS semanas,
  SUM(coalesce(dias_impacto, 0))    AS dias_impacto
FROM status_estruturado
WHERE data_status >= DATE'2026-07-18'
  AND causa_bloqueio NOT IN ('sem_bloqueio', 'nao_reportado')
GROUP BY projeto_id, causa_bloqueio
ORDER BY semanas DESC
"""),
    "ds_fornecedores": ("Desempenho por fornecedor", """
SELECT
  fornecedor,
  COUNT(DISTINCT fornecedor_como_veio)                       AS grafias_no_cadastro,
  COUNT(*)                                                   AS entregas,
  try_divide(SUM(CASE WHEN NOT em_aberto THEN prazo_real_dias END),
             SUM(CASE WHEN NOT em_aberto THEN prazo_prometido_dias END)) AS prazo_real_sobre_prometido,
  try_divide(count_if(NOT em_aberto AND data_entrega <= data_prometida),
             count_if(NOT em_aberto))                        AS pct_no_prazo,
  count_if(em_atraso)                                        AS em_atraso_hoje
FROM lakehouse_vertice.silver.entregas_fornecedor
GROUP BY fornecedor
ORDER BY prazo_real_sobre_prometido DESC
"""),
    "ds_atrasos": ("Entregas em atraso hoje", """
SELECT
  entrega_id,
  projeto_id,
  fornecedor,
  item,
  valor,
  data_pedido,
  data_prometida,
  datediff(DATE'2026-10-16', data_prometida) AS dias_em_atraso
FROM lakehouse_vertice.silver.entregas_fornecedor
WHERE em_atraso
ORDER BY dias_em_atraso DESC
"""),
}


def dataset(nome):
    titulo, sql = DATASETS[nome]
    linhas = [l + "\n" for l in sql.strip().splitlines()]
    return {"name": nome, "displayName": titulo, "queryLines": linhas}


# ---------------------------------------------------------------------------
# Widgets
# ---------------------------------------------------------------------------
def pos(x, y, w, h):
    return {"x": x, "y": y, "width": w, "height": h}


def campo(nome, expressao=None):
    return {"name": nome, "expression": expressao or f"`{nome}`"}


def texto(nome, linhas, posicao):
    return {"widget": {"name": nome, "multilineTextboxSpec": {"lines": linhas}}, "position": posicao}


def contador(nome, ds, coluna, titulo, formato, posicao, descricao=None):
    frame = {"showTitle": True, "title": titulo}
    if descricao:
        frame.update(description=descricao, showDescription=True)
    return {
        "widget": {
            "name": nome,
            "queries": [{"name": "main_query", "query": {
                "datasetName": ds, "fields": [campo(coluna)], "disaggregated": True}}],
            "spec": {"version": 2, "widgetType": "counter",
                     "encodings": {"value": {"fieldName": coluna, "displayName": titulo, "format": formato}},
                     "frame": frame},
        },
        "position": posicao,
    }


def tabela(nome, ds, colunas, titulo, posicao):
    """colunas: lista de (campo, rótulo, formato ou None)."""
    encod = []
    for c, rotulo, fmt in colunas:
        e = {"fieldName": c, "displayName": rotulo}
        if fmt:
            e["format"] = fmt
        encod.append(e)
    return {
        "widget": {
            "name": nome,
            "queries": [{"name": "main_query", "query": {
                "datasetName": ds, "fields": [campo(c) for c, _, _ in colunas], "disaggregated": True}}],
            "spec": {"version": 2, "widgetType": "table",
                     "encodings": {"columns": encod},
                     "frame": {"showTitle": True, "title": titulo}},
        },
        "position": posicao,
    }


def grafico(nome, tipo, ds, campos, encodings, titulo, posicao, filtros=None, extra_spec=None, descricao=None):
    query = {"datasetName": ds, "fields": campos, "disaggregated": False}
    if filtros:
        query["filters"] = [{"expression": f} for f in filtros]
    frame = {"showTitle": True, "title": titulo}
    if descricao:
        frame.update(description=descricao, showDescription=True)
    spec = {"version": 3, "widgetType": tipo, "encodings": encodings, "frame": frame}
    spec.update(extra_spec or {})
    return {"widget": {"name": nome, "queries": [{"name": "main_query", "query": query}], "spec": spec},
            "position": posicao}


# ---------------------------------------------------------------------------
# Página 1 · Portfólio
# ---------------------------------------------------------------------------
portfolio = [
    texto("titulo_portfolio", [
        "## Quais projetos estão atrasados, de quais clientes, e quanto esse atraso vai custar?\n", "\n",
        "Carteira em andamento na fotografia de 16/10/2026. SPI e CPI < 0,9 = atenção, < 0,8 = crítico.",
    ], pos(0, 0, 12, 2)),

    contador("kpi_carteira", "ds_kpis", "carteira", "Carteira em andamento", REAIS, pos(0, 2, 3, 3)),
    contador("kpi_spi", "ds_kpis", "spi", "SPI da carteira", INDICE, pos(3, 2, 3, 3),
             "Σ EV ÷ Σ PV · < 1 é atraso"),
    contador("kpi_cpi", "ds_kpis", "cpi", "CPI da carteira", INDICE, pos(6, 2, 3, 3),
             "Σ EV ÷ Σ AC · < 1 é estouro"),
    contador("kpi_estouro", "ds_kpis", "estouro_previsto", "Estouro previsto", REAIS, pos(9, 2, 3, 3),
             "EAC − orçamento, quando positivo"),
    contador("kpi_em_risco", "ds_kpis", "em_risco", "Projetos em risco", INTEIRO, pos(0, 5, 4, 3),
             "atenção + crítico"),
    contador("kpi_criticos", "ds_kpis", "criticos", "Críticos", INTEIRO, pos(4, 5, 4, 3),
             "SPI ou CPI < 0,8"),
    contador("kpi_melancias", "ds_kpis", "melancias", "Melancias", INTEIRO, pos(8, 5, 4, 3),
             "farol do gerente verde e SPI < 0,9"),

    grafico("estouro_por_projeto", "bar", "ds_projetos",
            [campo("projeto_id"), campo("situacao"), campo("sum(estouro_previsto)", "SUM(`estouro_previsto`)")],
            {"x": {"fieldName": "projeto_id", "displayName": "Projeto",
                   "scale": {"type": "categorical", "sort": {"by": "y-reversed"}}},
             "y": {"fieldName": "sum(estouro_previsto)", "displayName": "Estouro previsto",
                   "scale": {"type": "quantitative"}, "format": REAIS},
             "color": {"fieldName": "situacao", "displayName": "Situação",
                       "scale": {"type": "categorical", "mappings": CORES_SITUACAO}}},
            "Estouro previsto por projeto", pos(0, 8, 6, 6),
            filtros=["`estouro_previsto` > 0"], descricao="só projetos com estouro"),

    grafico("spi_x_cpi", "scatter", "ds_projetos",
            [campo("spi"), campo("cpi"), campo("situacao"), campo("projeto_id"), campo("nome")],
            {"x": {"fieldName": "spi", "displayName": "SPI (prazo)", "scale": {"type": "quantitative"}, "format": INDICE},
             "y": {"fieldName": "cpi", "displayName": "CPI (custo)", "scale": {"type": "quantitative"}, "format": INDICE},
             "color": {"fieldName": "situacao", "displayName": "Situação",
                       "scale": {"type": "categorical", "mappings": CORES_SITUACAO}},
             "extra": [{"fieldName": "projeto_id", "displayName": "Projeto"}, {"fieldName": "nome", "displayName": "Nome"}]},
            "SPI × CPI · um ponto por projeto", pos(6, 8, 6, 6),
            extra_spec={"annotations": [
                {"type": "vertical-line", "encodings": {"x": {"dataValue": "0.9", "dataType": "DOUBLE"},
                                                        "label": {"value": "SPI 0,9"}, "color": {"value": ATENCAO}}},
                {"type": "horizontal-line", "encodings": {"y": {"dataValue": "0.9", "dataType": "DOUBLE"},
                                                          "label": {"value": "CPI 0,9"}, "color": {"value": ATENCAO}}},
            ]}),

    grafico("spi_cpi_semanal", "line", "ds_carteira_semanal",
            [campo("semana"), campo("spi"), campo("cpi")],
            {"x": {"fieldName": "semana", "displayName": "Semana", "scale": {"type": "temporal"}},
             "y": {"scale": {"type": "quantitative"}, "format": INDICE,
                   "fields": [{"fieldName": "spi", "displayName": "SPI"},
                              {"fieldName": "cpi", "displayName": "CPI"}]}},
            "SPI e CPI semanais da carteira", pos(0, 14, 12, 5),
            extra_spec={"annotations": [
                {"type": "horizontal-line", "encodings": {"y": {"dataValue": "0.9", "dataType": "DOUBLE"},
                                                          "label": {"value": "atenção (0,9)"}, "color": {"value": ATENCAO}}},
            ]}),

    tabela("projetos_em_andamento", "ds_projetos", [
        ("projeto_id", "Projeto", None),
        ("nome", "Nome", None),
        ("cliente", "Cliente", None),
        ("gerente_projeto", "Gerente", None),
        ("situacao", "Situação", None),
        ("farol_do_gerente", "Farol do gerente", None),
        ("farol_calculado", "Farol pelo número", None),
        ("melancia", "Melancia", None),
        ("spi", "SPI", INDICE),
        ("cpi", "CPI", INDICE),
        ("estouro_previsto", "Estouro previsto", REAIS),
        ("atraso_projetado_dias", "Atraso projetado (dias)", INTEIRO),
        ("termino_projetado", "Término projetado", None),
    ], "Projetos em andamento · o farol do gerente ao lado do farol pelo número", pos(0, 19, 12, 9)),
]
# o grid da skill tem a primeira linha de gráficos com 2 colunas, então o filtro de estouro fica no widget
# (o mesmo dataset alimenta a tabela com todos os projetos em andamento)

# ---------------------------------------------------------------------------
# Página 2 · Pessoas
# ---------------------------------------------------------------------------
pessoas = [
    texto("titulo_pessoas", [
        "## Tenho gente parada enquanto outro projeto pede gente?\n", "\n",
        "Timesheet das últimas 12 semanas (até 16/10/2026) ao lado das causas de bloqueio que os gerentes escreveram nos últimos 90 dias.",
    ], pos(0, 0, 12, 2)),

    grafico("top15_custo_ocioso", "bar", "ds_custo_ocioso",
            [campo("pessoa"), campo("sum(custo_ocioso)", "SUM(`custo_ocioso`)")],
            {"x": {"fieldName": "sum(custo_ocioso)", "displayName": "Custo da hora parada",
                   "scale": {"type": "quantitative"}, "format": REAIS},
             "y": {"fieldName": "pessoa", "displayName": "Pessoa",
                   "scale": {"type": "categorical", "sort": {"by": "x-reversed"}}}},
            "Top 15 pessoas por custo da hora parada (12 semanas)", pos(0, 2, 6, 8)),

    grafico("causas_por_projeto", "bar", "ds_causas",
            [campo("projeto_id"), campo("causa_bloqueio"), campo("sum(semanas)", "SUM(`semanas`)")],
            {"x": {"fieldName": "projeto_id", "displayName": "Projeto",
                   "scale": {"type": "categorical", "sort": {"by": "y-reversed"}}},
             "y": {"fieldName": "sum(semanas)", "displayName": "Semanas com o bloqueio",
                   "scale": {"type": "quantitative"}},
             "color": {"fieldName": "causa_bloqueio", "displayName": "Causa",
                       "scale": {"type": "categorical"}}},
            "Causas de bloqueio por projeto (últimos 90 dias)", pos(6, 2, 6, 8)),

    tabela("utilizacao_pessoa_projeto", "ds_utilizacao", [
        ("colaborador_id", "Pessoa", None),
        ("nome", "Nome", None),
        ("papel", "Papel", None),
        ("senioridade", "Senioridade", None),
        ("projeto_id", "Projeto", None),
        ("horas_disponiveis", "Horas disponíveis", HORAS),
        ("horas_apontadas", "Horas apontadas", HORAS),
        ("horas_ociosas", "Horas ociosas", HORAS),
        ("utilizacao", "Utilização", PERCENTUAL),
        ("custo_ocioso", "Custo da hora parada", REAIS),
    ], "Utilização por pessoa e projeto (12 semanas) · da mais parada à mais ocupada", pos(0, 10, 12, 9)),
]

# ---------------------------------------------------------------------------
# Página 3 · Fornecedores
# ---------------------------------------------------------------------------
fornecedores = [
    texto("titulo_fornecedores", [
        "## O que vai dar errado no próximo mês? Qual fornecedor não cumpre prazo?\n", "\n",
        "Entregas das consultorias: prometido × entregue. Em atraso = em aberto com data prometida antes de 16/10/2026.",
    ], pos(0, 0, 12, 2)),

    tabela("desempenho_fornecedor", "ds_fornecedores", [
        ("fornecedor", "Fornecedor", None),
        ("grafias_no_cadastro", "Grafias no cadastro", INTEIRO),
        ("entregas", "Entregas", INTEIRO),
        ("prazo_real_sobre_prometido", "Prazo real ÷ prometido", INDICE),
        ("pct_no_prazo", "% no prazo", PERCENTUAL),
        ("em_atraso_hoje", "Em atraso hoje", INTEIRO),
    ], "Desempenho por fornecedor", pos(0, 2, 12, 6)),

    tabela("entregas_em_atraso", "ds_atrasos", [
        ("entrega_id", "Entrega", None),
        ("projeto_id", "Projeto", None),
        ("fornecedor", "Fornecedor", None),
        ("item", "Item", None),
        ("valor", "Valor", REAIS),
        ("data_pedido", "Pedido", None),
        ("data_prometida", "Prometida", None),
        ("dias_em_atraso", "Dias em atraso", INTEIRO),
    ], "Entregas em atraso hoje", pos(0, 8, 12, 6)),
]


def pagina(nome, titulo, layout):
    return {"name": nome, "displayName": titulo, "pageType": "PAGE_TYPE_CANVAS",
            "layoutVersion": "GRID_V1", "layout": layout}


DASHBOARD = {
    "datasets": [dataset(n) for n in DATASETS],
    "pages": [
        pagina("portfolio", "Portfólio", portfolio),
        pagina("pessoas", "Pessoas", pessoas),
        pagina("fornecedores", "Fornecedores", fornecedores),
    ],
    "uiSettings": {
        "theme": {
            "canvasBackgroundColor": {"light": "#F5F7FA", "dark": FUNDO_ESCURO},
            "widgetBackgroundColor": {"light": "#FFFFFF", "dark": "#1C1C24"},
            "widgetBorderColor":     {"light": "#FFFFFF", "dark": "#1C1C24"},
            "fontColor":             {"light": FUNDO_ESCURO, "dark": "#E8ECF0"},
            "selectionColor":        {"light": AZUL, "dark": CIANO},
            "visualizationColors": [AZUL, CIANO, "#8B5CF6", "#F59E0B", "#10B981", "#EC4899", "#64748B", "#A3E635"],
            "widgetHeaderAlignment": "LEFT",
        }
    },
}


def main():
    SAIDA.write_text(json.dumps(DASHBOARD, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    widgets = sum(len(p["layout"]) for p in DASHBOARD["pages"])
    print(f"{SAIDA.relative_to(SAIDA.parent.parent)}: {len(DASHBOARD['datasets'])} datasets, "
          f"{len(DASHBOARD['pages'])} páginas, {widgets} widgets")


if __name__ == "__main__":
    main()
