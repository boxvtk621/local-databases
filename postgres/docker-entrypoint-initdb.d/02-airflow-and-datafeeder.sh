#!/bin/sh
# Создаёт роли и БД для Apache Airflow (метаданные) и DataFeeder (фид).
# Выполняется только при первом создании volume Postgres.
# Пароли через psql :'…' — допустимы кавычки и спецсимволы без ручного экранирования.
set -eu
psql -v ON_ERROR_STOP=1 \
  -v "airflow_user=${AIRFLOW_METADATA_USER}" \
  -v "airflow_pass=${AIRFLOW_METADATA_PASSWORD}" \
  -v "airflow_db=${AIRFLOW_METADATA_DB}" \
  -v "feed_user=${FEED_POSTGRES_USER}" \
  -v "feed_pass=${FEED_POSTGRES_PASSWORD}" \
  -v "feed_db=${FEED_POSTGRES_DB}" \
  --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<'EOSQL'
CREATE USER :"airflow_user" WITH PASSWORD :'airflow_pass';
CREATE DATABASE :"airflow_db" OWNER :"airflow_user";
CREATE USER :"feed_user" WITH PASSWORD :'feed_pass';
CREATE DATABASE :"feed_db" OWNER :"feed_user";
EOSQL
