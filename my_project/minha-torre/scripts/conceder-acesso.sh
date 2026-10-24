#!/usr/bin/env bash
# Dá ao service principal do app acesso de leitura à gold e à silver.
#
# O app é um usuário do Unity Catalog e nasce sem acesso a nada: CAN_USE no warehouse
# dá o computador, não o dado. Sem estes GRANTs o build falha no typegen com
# INSUFFICIENT_PERMISSIONS. Rode depois do primeiro `databricks bundle deploy`.
#
# Uso:
#   bash scripts/conceder-acesso.sh <perfil> [nome-do-app]
#   bash scripts/conceder-acesso.sh lakehouse_vertice minha-torre
set -euo pipefail

PERFIL="${1:?uso: bash scripts/conceder-acesso.sh <perfil> [nome-do-app]}"
APP="${2:-minha-torre}"
CATALOGO="lakehouse_vertice"

# O principal do GRANT é o application id (client id) do service principal do app
SP=$(databricks apps get "$APP" --profile "$PERFIL" -o json \
  | python -c "import json, sys; print(json.load(sys.stdin)['service_principal_client_id'])")
echo "app $APP · service principal $SP"

GRANTS=(
  "GRANT USE CATALOG ON CATALOG ${CATALOGO} TO \`${SP}\`"
  "GRANT USE SCHEMA ON SCHEMA ${CATALOGO}.gold TO \`${SP}\`"
  "GRANT SELECT ON SCHEMA ${CATALOGO}.gold TO \`${SP}\`"
  "GRANT USE SCHEMA ON SCHEMA ${CATALOGO}.silver TO \`${SP}\`"
  "GRANT SELECT ON SCHEMA ${CATALOGO}.silver TO \`${SP}\`"
)

for g in "${GRANTS[@]}"; do
  echo "  $g"
  databricks experimental aitools tools query "$g" --profile "$PERFIL" > /dev/null
done

echo "ok: agora rode  databricks apps deploy --profile $PERFIL"
