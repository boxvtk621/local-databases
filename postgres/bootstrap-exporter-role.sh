#!/bin/sh
# Создаёт роль postgres_exporter при существующем volume (initdb не запускается повторно).
# Вызывается из сервиса postgres-exporter-bootstrap в docker-compose.yml.
# Проверка «роль есть» через stdin + :'eu' — в -c одинарная строка psql не подставляет переменные.
set -e
if psql -v "eu=${POSTGRES_EXPORTER_USER}" -tA <<'EOSQL' | grep -q 1
SELECT 1 FROM pg_roles WHERE rolname = :'eu';
EOSQL
then
  echo "postgres_exporter: role exists"
  exit 0
fi
psql -v ON_ERROR_STOP=1 \
  -v "eu=${POSTGRES_EXPORTER_USER}" \
  -v "ep=${POSTGRES_EXPORTER_PASSWORD}" \
  <<'EOSQL'
CREATE USER :"eu" WITH PASSWORD :'ep';
GRANT pg_monitor TO :"eu";
EOSQL
echo "postgres_exporter: role created"
