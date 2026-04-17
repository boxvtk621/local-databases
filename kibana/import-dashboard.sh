#!/usr/bin/env bash
# Импорт дашборда и связанных объектов в Kibana (8.12).
# Переменные: KIBANA_URL (по умолчанию http://127.0.0.1/kibana), ELASTIC_USER, ELASTIC_PASSWORD.
set -euo pipefail
KIBANA_URL="${KIBANA_URL:-http://127.0.0.1/kibana}"
ELASTIC_USER="${ELASTIC_USER:-elastic}"
ELASTIC_PASSWORD="${ELASTIC_PASSWORD:-elastic_local}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NDJSON="${1:-${SCRIPT_DIR}/db-logs-dashboard.ndjson}"

curl -sS -u "${ELASTIC_USER}:${ELASTIC_PASSWORD}" \
  -H "kbn-xsrf: true" \
  -X POST "${KIBANA_URL%/}/api/saved_objects/_import?overwrite=true" \
  -F "file=@${NDJSON}"

echo
