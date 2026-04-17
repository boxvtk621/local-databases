#!/bin/sh
# Пользователь только для postgres_exporter (метрики). Только при первом создании volume.
set -eu
if psql -v "eu=${POSTGRES_EXPORTER_USER}" -tA <<'EOSQL' | grep -q 1
SELECT 1 FROM pg_roles WHERE rolname = :'eu';
EOSQL
then
  exit 0
fi
psql -v ON_ERROR_STOP=1 \
  -v "eu=${POSTGRES_EXPORTER_USER}" \
  -v "ep=${POSTGRES_EXPORTER_PASSWORD}" \
  --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<'EOSQL'
CREATE USER :"eu" WITH PASSWORD :'ep';
GRANT pg_monitor TO :"eu";
EOSQL
