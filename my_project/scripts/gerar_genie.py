#!/usr/bin/env python3
"""Gera resources/farol.geniespace.json: o Genie "Farol · Diretoria" como código.

O JSON é o serialized_space (versão 2). Os ids são determinísticos (hash do conteúdo,
32 caracteres hex): o mesmo texto gera o mesmo id, então o diff no Git mostra só o que
mudou de verdade. Não edite o Genie no workspace (o próximo deploy recusa com
"modified remotely"): mude este script, gere o JSON e faça deploy.

A tabela do modelo (gold.score_estouro_30d) entra SÓ se existir. Sem ela, nenhuma
instrução nem exemplo fala de score.

Uso:
  python scripts/gerar_genie.py --profile <perfil>
"""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path

SAIDA = Path(__file__).resolve().parent.parent / "resources" / "farol.geniespace.json"
CATALOGO = "lakehouse_vertice"
SCORE = f"{CATALOGO}.gold.score_estouro_30d"


def novo_id(tipo: str, texto: str) -> str:
    return hashlib.md5(f"{tipo}:{texto}".encode("utf-8")).hexdigest()


def tabela_existe(nome: str, perfil: str) -> bool:
    r = subprocess.run(["databricks", "tables", "exists", nome, "--profile", perfil, "-o", "json"],
                       capture_output=True, text=True, encoding="utf-8")
    if r.returncode != 0:
        raise SystemExit(f"não consegui conferir {nome}: {r.stderr.strip()}")
    return bool(json.loads(r.stdout).get("table_exists"))


# ---------------------------------------------------------------------------
# Fontes
# ---------------------------------------------------------------------------
TABELAS = {
    f"{CATALOGO}.gold.fato_projeto_semana": [
        {"column_name": "farol_do_gerente", "enable_format_assistance": True, "enable_entity_matching": True},
    ],
    f"{CATALOGO}.gold.projeto_situacao_atual": [
        {"column_name": "cliente", "enable_format_assistance": True, "enable_entity_matching": True},
        {"column_name": "farol_calculado", "enable_format_assistance": True, "enable_entity_matching": True},
        {"column_name": "farol_do_gerente", "enable_format_assistance": True, "enable_entity_matching": True},
        {"column_name": "ferramenta", "enable_format_assistance": True, "enable_entity_matching": True},
        {"column_name": "projeto", "description": ["Código do projeto (PRJ-000), igual a projeto_id. Use para responder 'qual projeto' ou 'códigos dos projetos'."]},
        {"column_name": "segmento", "enable_format_assistance": True, "enable_entity_matching": True},
        {"column_name": "situacao", "enable_format_assistance": True, "enable_entity_matching": True},
    ],
    f"{CATALOGO}.gold.status_estruturado": [
        {"column_name": "causa_bloqueio", "enable_format_assistance": True, "enable_entity_matching": True},
    ],
    f"{CATALOGO}.gold.utilizacao_pessoa_semana": [
        {"column_name": "papel", "enable_format_assistance": True, "enable_entity_matching": True},
    ],
    f"{CATALOGO}.silver.entregas_fornecedor": [
        {"column_name": "fornecedor", "enable_format_assistance": True, "enable_entity_matching": True},
    ],
}
METRIC_VIEWS = [f"{CATALOGO}.gold.mv_projetos"]

PERGUNTAS_DO_DONO = [
    "Quais projetos estão atrasados, e de quais clientes?",
    "Quanto esse atraso vai me custar?",
    "Tenho gente parada enquanto outro projeto pede gente?",
    "O que vai dar errado no próximo mês?",
]

# ---------------------------------------------------------------------------
# Instruções de texto (uma só entrada, várias linhas)
# ---------------------------------------------------------------------------
INSTRUCOES = [
    "Você responde ao dono e à diretoria da Vértice Tecnologia, que não escrevem SQL. Responda em português, com R$ e índices com 2 casas decimais.",
    "HOJE = 2026-10-16 (sexta-feira). Nunca use current_date(). 'Últimos 90 dias' = data_status >= DATE'2026-07-18'. 'Últimas 12 semanas' = semana > DATE'2026-07-24' AND semana <= DATE'2026-10-16'. 'Próximo mês' = de 2026-10-17 a 2026-11-16.",
    "Carteira = projetos com status = 'em_andamento' (41 projetos). Sempre filtre status = 'em_andamento' quando a pergunta for sobre a carteira, situação, risco, estouro ou atraso, a não ser que peçam os concluídos.",
    "Fórmulas: SPI = EV ÷ PV (abaixo de 1 é atraso). CPI = EV ÷ AC (abaixo de 1 é estouro de custo). EAC = orçamento ÷ CPI. Estouro previsto = EAC − orçamento, só quando positivo. Margem projetada = (valor do contrato − EAC) ÷ valor do contrato. Atraso projetado (dias) = duração do baseline ÷ SPI − duração do baseline.",
    "Regras de corte: SPI ou CPI abaixo de 0,9 = atenção, abaixo de 0,8 = crítico. A coluna situacao já traz isso: 'ok', 'atenção', 'crítico' ou 'concluído' (com acento). 'Projetos em risco' ou 'atrasados' = situacao IN ('atenção', 'crítico').",
    "Totais de HOJE da carteira (SPI, CPI, estouro previsto, carteira, margem, quantidade de críticos, em risco, melancias): use a metric view lakehouse_vertice.gold.mv_projetos com MEASURE(), por exemplo SELECT ROUND(MEASURE(spi), 2) FROM lakehouse_vertice.gold.mv_projetos. Ela já filtra os projetos em andamento. Razão da carteira é sempre soma sobre soma, nunca média de SPIs.",
    "Ranking, lista, contagem ou valor de UM projeto (qual projeto tem o maior estouro, o SPI do PRJ-011, quais são os críticos, quantos usam Excel): use lakehouse_vertice.gold.projeto_situacao_atual. A coluna projeto é o CÓDIGO do projeto (PRJ-000, igual a projeto_id) e nome é o nome por extenso. Quando pedirem 'qual projeto' ou 'os códigos', devolva a coluna projeto. Para um projeto específico, filtre projeto = 'PRJ-000'.",
    "Histórico semanal (o SPI de um projeto numa semana, a evolução): use lakehouse_vertice.gold.fato_projeto_semana. semana é sempre uma sexta-feira. PV, EV e AC no fato são ACUMULADOS até a semana: nunca some semanas. Para uma semana específica, filtre semana = DATE'aaaa-mm-dd'.",
    "Farol: farol_do_gerente é o que o gerente publicou no status. farol_calculado é a regra do manual pelo SPI (verde com SPI de 0,95 ou mais, amarelo de 0,90 ou mais, vermelho abaixo). Melancia = projeto em andamento com farol do gerente verde e SPI abaixo de 0,9: use a coluna melancia (WHERE melancia). 'Farol verde mas atrasado' é melancia.",
    "'Por que o projeto X atrasou?' ou 'qual a causa': use lakehouse_vertice.gold.status_estruturado dos últimos 90 dias, sem causa_bloqueio 'sem_bloqueio' e 'nao_reportado', agrupando por causa_bloqueio e contando as semanas (a principal causa é a mais frequente), com a soma de dias_impacto. Acrescente o SPI de hoje do projeto (projeto_situacao_atual). Se a causa for falta_sre, mostre também os SREs ociosos (papel = 'sre' com utilização abaixo de 20% nas últimas 12 semanas).",
    "Gente parada / ociosa: utilização = SUM(horas_apontadas) ÷ SUM(horas_disponiveis) em lakehouse_vertice.gold.utilizacao_pessoa_semana nas últimas 12 semanas, agrupando por colaborador_id. Parado = utilização abaixo de 0,2. 'Quem pede gente' = projetos com causa_bloqueio falta_sre ou rotatividade no status_estruturado dos últimos 90 dias.",
    "Fornecedor: use lakehouse_vertice.silver.entregas_fornecedor. 'Quem mais atrasa' = maior média de prazo_real_dias ÷ prazo_prometido_dias por fornecedor (AVG(prazo_real_dias / prazo_prometido_dias)). Entregas em atraso hoje = WHERE em_atraso. A CodeForge Consultoria Ltda já vem com o nome normalizado.",
    "'O que vai dar errado no próximo mês?': junte (1) as entregas de consultoria em atraso hoje (silver.entregas_fornecedor WHERE em_atraso) e (2) o change freeze de varejo da Black Friday, de 01/11/2026 a 10/01/2027, que trava os projetos de e-commerce em andamento: lower(tipo_projeto) LIKE '%commerce%' OR LIKE '%checkout%' OR LIKE '%marketplace%'. Termine com uma recomendação curta do que fazer agora.",
    "'Quais clientes': devolva cada cliente UMA vez (SELECT DISTINCT cliente).",
]

INSTRUCOES_SCORE = [
    f"Modelo de estouro: {SCORE} traz, por projeto, prob_estouro_30d (de 0 a 1), ranking, faixa_risco ('alto' com 0,5 ou mais, 'medio' com 0,2 ou mais, 'baixo') e principais_fatores. Use sempre a data_referencia mais recente. Projeto que já está abaixo de 0,9 hoje tem prob 1,0.",
    f"No 'o que vai dar errado no próximo mês', acrescente (3) os projetos com situacao = 'ok' hoje e faixa_risco 'alto' ou 'medio' no {SCORE}, com principais_fatores.",
]

# ---------------------------------------------------------------------------
# Exemplos de SQL (um por pergunta do dono), testados no warehouse
# ---------------------------------------------------------------------------
EXEMPLOS = [
    (PERGUNTAS_DO_DONO[0],
     "SELECT projeto, nome, cliente, situacao, ROUND(spi, 2) AS spi, ROUND(cpi, 2) AS cpi, atraso_projetado_dias, farol_do_gerente, farol_calculado, melancia "
     f"FROM {CATALOGO}.gold.projeto_situacao_atual WHERE status = 'em_andamento' AND situacao IN ('crítico', 'atenção') "
     "ORDER BY CASE situacao WHEN 'crítico' THEN 1 ELSE 2 END, LEAST(spi, cpi)"),
    (PERGUNTAS_DO_DONO[1],
     "SELECT ROUND(MEASURE(estouro_previsto), 2) AS estouro_previsto, ROUND(MEASURE(eac), 2) AS eac, ROUND(MEASURE(margem_projetada), 4) AS margem_projetada, ROUND(MEASURE(cpi), 2) AS cpi_carteira "
     f"FROM {CATALOGO}.gold.mv_projetos"),
    (PERGUNTAS_DO_DONO[2],
     "WITH parados AS (SELECT colaborador_id, nome, papel, projeto_id, SUM(horas_apontadas) / SUM(horas_disponiveis) AS utilizacao, SUM(custo_ocioso) AS custo_ocioso_12_semanas "
     f"FROM {CATALOGO}.gold.utilizacao_pessoa_semana WHERE semana > DATE'2026-07-24' AND semana <= DATE'2026-10-16' "
     "GROUP BY colaborador_id, nome, papel, projeto_id HAVING SUM(horas_apontadas) / SUM(horas_disponiveis) < 0.2), "
     "pedidos AS (SELECT projeto_id, causa_bloqueio, COUNT(*) AS semanas, SUM(COALESCE(dias_impacto, 0)) AS dias_impacto "
     f"FROM {CATALOGO}.gold.status_estruturado WHERE data_status >= DATE'2026-07-18' AND causa_bloqueio IN ('falta_sre', 'rotatividade') GROUP BY projeto_id, causa_bloqueio) "
     "SELECT p.colaborador_id, p.nome, p.papel, p.projeto_id AS projeto_atual, ROUND(p.utilizacao, 3) AS utilizacao, ROUND(p.custo_ocioso_12_semanas, 2) AS custo_ocioso_12_semanas, "
     "d.projeto_id AS projeto_que_pede_gente, d.causa_bloqueio, d.semanas, d.dias_impacto "
     "FROM parados p LEFT JOIN pedidos d ON (p.papel = 'sre' AND d.causa_bloqueio = 'falta_sre') OR (p.papel <> 'sre' AND d.causa_bloqueio = 'rotatividade') "
     "ORDER BY p.custo_ocioso_12_semanas DESC, d.dias_impacto DESC"),
    (PERGUNTAS_DO_DONO[3],
     "SELECT 'entrega de consultoria em atraso' AS risco, e.projeto_id, e.fornecedor AS detalhe, e.data_prometida AS data_referencia, DATEDIFF(DATE'2026-10-16', e.data_prometida) AS dias "
     f"FROM {CATALOGO}.silver.entregas_fornecedor e WHERE e.em_atraso "
     "UNION ALL "
     "SELECT 'change freeze de varejo (01/11/2026 a 10/01/2027)' AS risco, p.projeto_id, concat(p.tipo_projeto, ' · ', p.cliente) AS detalhe, DATE'2026-11-01' AS data_referencia, DATEDIFF(DATE'2027-01-10', DATE'2026-11-01') AS dias "
     f"FROM {CATALOGO}.gold.projeto_situacao_atual p WHERE p.status = 'em_andamento' "
     "AND (lower(p.tipo_projeto) LIKE '%commerce%' OR lower(p.tipo_projeto) LIKE '%checkout%' OR lower(p.tipo_projeto) LIKE '%marketplace%') "
     "ORDER BY risco, projeto_id"),
]

EXEMPLO_SCORE = (
    "Qual a chance de o PRJ-024 estourar?",
    f"SELECT projeto_id, ROUND(prob_estouro_30d, 2) AS prob_estouro_30d, faixa_risco, principais_fatores, data_referencia FROM {SCORE} "
    f"WHERE projeto_id = 'PRJ-024' AND data_referencia = (SELECT MAX(data_referencia) FROM {SCORE})",
)


def montar(com_score: bool) -> dict:
    tabelas = dict(TABELAS)
    instrucoes = list(INSTRUCOES)
    exemplos = list(EXEMPLOS)
    if com_score:
        tabelas[SCORE] = []
        instrucoes += INSTRUCOES_SCORE
        exemplos.append(EXEMPLO_SCORE)

    def fonte(nome, colunas):
        f = {"identifier": nome}
        if colunas:
            f["column_configs"] = sorted(colunas, key=lambda c: c["column_name"])
        return f

    texto = [linha + "\n" for linha in instrucoes]
    return {
        "version": 2,
        "config": {
            "sample_questions": sorted(
                [{"id": novo_id("pergunta", q), "question": [q]} for q in PERGUNTAS_DO_DONO],
                key=lambda x: x["id"]),
        },
        "data_sources": {
            "tables": sorted([fonte(n, c) for n, c in tabelas.items()], key=lambda t: t["identifier"]),
            "metric_views": sorted([{"identifier": n} for n in METRIC_VIEWS], key=lambda t: t["identifier"]),
        },
        "instructions": {
            "text_instructions": [{"id": novo_id("instrucao", "".join(texto)), "content": texto}],
            "example_question_sqls": sorted(
                [{"id": novo_id("exemplo", q), "question": [q], "sql": [s]} for q, s in exemplos],
                key=lambda x: x["id"]),
        },
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--profile", required=True, help="perfil do ~/.databrickscfg (para conferir se o score existe)")
    args = ap.parse_args()

    com_score = tabela_existe(SCORE, args.profile)
    espaco = montar(com_score)

    ids = [x["id"] for x in espaco["config"]["sample_questions"]] + \
          [x["id"] for x in espaco["instructions"]["text_instructions"]] + \
          [x["id"] for x in espaco["instructions"]["example_question_sqls"]]
    assert len(ids) == len(set(ids)), "ids repetidos"

    SAIDA.write_text(json.dumps(espaco, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"{SAIDA.relative_to(SAIDA.parent.parent)}: {len(espaco['data_sources']['tables'])} tabelas + "
          f"{len(espaco['data_sources']['metric_views'])} metric view, {len(INSTRUCOES) + (len(INSTRUCOES_SCORE) if com_score else 0)} linhas de instrução, "
          f"{len(espaco['instructions']['example_question_sqls'])} exemplos de SQL · score {'incluído' if com_score else 'ausente (não incluído)'}")


if __name__ == "__main__":
    main()
