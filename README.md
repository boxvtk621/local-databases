# Локальные базы данных

[Docker Compose](https://docs.docker.com/compose/)-стек: PostgreSQL, MongoDB, Elasticsearch, Valkey, Qdrant, веб-портал (nginx) и сеть `databases_net`. Учётки **только для локальной разработки**.

Адреса вида `http://db.local/...` в этом файле — **только для вашей машины** после `docker compose up` и настройки `hosts`; на странице репозитория на GitHub они не открываются.

![Скриншот локального веб-портала](docs/images/portal.png)

## Возможности

После настройки `db.local` в `hosts` UI открываются по путям относительно `http://db.local` (порт портала — **`PORTAL_HOST_PORT`**, по умолчанию 80), кроме Qdrant — см. колонку «Путь / порт».

| Компонент | Порт на хосте | UI (локально) |
|-----------|---------------|---------------|
| **PostgreSQL** 16 | 5432 | pgAdmin — `http://db.local/pgadmin/` |
| **MongoDB** 7 | 27017 | mongo-express — `http://db.local/mongo/` |
| **Elasticsearch** 8.12 | 9200 | Kibana — `http://db.local/kibana/` (логи СУБД — см. [ниже](#database-logs-fluentd)) |
| **Valkey** 8 | 6379 | Redis Insight — `http://db.local/valkey-insight/` (Basic у nginx) |
| **Qdrant** 1.13 | 6333 | Dashboard — `http://db.local:6333/dashboard` (не за nginx :80) |
| **Портал** | см. `PORTAL_HOST_PORT` в [`.env.example`](.env.example) (по умолчанию **80**) | `http://db.local/` (или с портом, если не 80) |

Порты админок **5050 / 8081 / 5601 / 5540** на хост не проброшены — только через nginx.

<h2 id="configuration">Конфигурация</h2>

Параметры стека задаются через файл **`.env`** в корне репозитория. Шаблон — [`.env.example`](.env.example):

```bash
cp .env.example .env
```

Если `.env` нет, подставляются значения по умолчанию из [`docker-compose.yml`](docker-compose.yml) (совпадают с `.env.example`). Файл `.env` в Git не коммитится (см. [`.gitignore`](.gitignore)).

При смене паролей или `PORTAL_PUBLIC_ORIGIN` / `KIBANA_PUBLIC_URL` обновите строки подключения в своих приложениях и при необходимости раздел [Домен `db.local`](#db-local). Пароль HTTP Basic перед Redis Insight — в [`proxy/redisinsight.htpasswd`](proxy/redisinsight.htpasswd) (отдельно от `.env`).

## Быстрый старт

```bash
cp .env.example .env   # опционально; можно править под себя
docker compose up -d
```

В `hosts` (см. [ниже](#db-local)): `127.0.0.1 db.local` — в браузере откройте `http://db.local/` (у вас локально).

```bash
docker compose down          # volumes сохраняются
docker compose down -v       # сброс: postgres_data, mongo_data, es_data, pgadmin_data, valkey_data, redisinsight_data, qdrant_data
```

## Требования

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose v2](https://docs.docker.com/compose/) (`docker compose`)

## Схема

```mermaid
flowchart LR
  host[Host]
  portal[portal_nginx]
  subgraph data_ports [DB_ports_on_host]
    pg[PostgreSQL_5432]
    mongo[MongoDB_27017]
    valkey[Valkey_6379]
    es[Elasticsearch_9200]
    qdrant[Qdrant_6333]
  end
  subgraph ui_behind_proxy [Admin_UIs_behind_portal]
    pgadmin[pgAdmin]
    mexpress[mongo-express]
    kibana[Kibana]
    ri[Redis_Insight]
  end
  host -->|http_db.local| portal
  portal --> pgadmin
  portal --> mexpress
  portal --> kibana
  portal --> ri
  host --> data_ports
```

## Содержание

- [Конфигурация](#configuration)
- [Хост и Docker](#host-and-docker)
- [Другие контейнеры](#external-compose)
- [db.local](#db-local)
- [Портал nginx](#web-portal)
- [PostgreSQL](#postgresql) · [MongoDB](#mongodb) · [Elasticsearch](#elasticsearch) · [Логи СУБД (Fluentd → Elasticsearch)](#database-logs-fluentd) · [Qdrant](#qdrant) · [Valkey](#valkey)

---

<h2 id="host-and-docker">Хост и Docker</h2>

| Клиент | Хост |
|--------|------|
| С хоста (IDE, MCP) | `db.local` (после `hosts`) или `localhost` / `127.0.0.1` для СУБД |
| В сети `databases_net` | `postgres`, `mongodb`, `valkey`, `elasticsearch`, `qdrant`; веб — `portal` ([`docker-compose.yml`](docker-compose.yml)) |
| Контейнер вне сети | хост: `host.docker.internal` (Desktop) или IP хоста / bridge |

Внутри чужого контейнера `localhost` — не ваши базы; до портов на машине — `host.docker.internal` или IP хоста.

**Пример переменных для приложения на хосте** (подставьте свои пароли из `.env`, если меняли значения из [`.env.example`](.env.example); `db.local` в `hosts`):

```text
DATABASE_URL=postgresql://postgres:postgres@db.local:5432/postgres
MONGODB_URI=mongodb://admin:admin@db.local:27017/?authSource=admin
ELASTICSEARCH_URL=http://elastic:elastic_local@db.local:9200
REDIS_URL=redis://valkey:valkey_local@db.local:6379
QDRANT_URL=http://db.local:6333
QDRANT_API_KEY=qdrant_local
```

**MCP (кратко)**

- **MongoDB:** `MDB_MCP_CONNECTION_STRING` как `MONGODB_URI`; опционально `MDB_MCP_READ_ONLY=true`.
- **PostgreSQL** ([crystaldba/postgres-mcp](https://github.com/crystaldba/postgres-mcp)): в контейнере MCP — `DATABASE_URI` с `host.docker.internal:5432`, `docker run … --add-host=host.docker.internal:host-gateway`.
- **Elasticsearch** (`docker.elastic.co/mcp/elasticsearch`): `ES_URL=http://host.docker.internal:9200`, не `127.0.0.1`; `ES_USERNAME`/`ES_PASSWORD` как в compose.
- **Valkey** ([mcp/redis](https://github.com/redis/mcp-redis)): `REDIS_HOST=host.docker.internal`, `REDIS_PORT=6379`, `REDIS_USERNAME=valkey`, `REDIS_PWD=valkey_local`.
- **Qdrant** ([mcp-server-qdrant](https://github.com/qdrant/mcp-server-qdrant)): образ `ghcr.io/astral-sh/uv:…`, `QDRANT_URL=http://host.docker.internal:6333`, том `cursor-qdrant-mcp-cache:/root/.cache`, `HF_HOME`/`UV_CACHE_DIR` в кэше; первый старт может быть долгим.
- **Docker MCP Toolkit:** [документация](https://docs.docker.com/ai/mcp-catalog-and-toolkit/get-started/), `docker mcp client connect cursor --global` → `MCP_DOCKER`.

<details>
<summary>Фрагмент <code>~/.cursor/mcp.json</code></summary>

```json
{
  "mcpServers": {
    "mongodb": {
      "command": "npx",
      "args": ["-y", "mongodb-mcp-server"],
      "env": {
        "MDB_MCP_CONNECTION_STRING": "mongodb://admin:admin@127.0.0.1:27017/?authSource=admin",
        "MDB_MCP_READ_ONLY": "true"
      }
    },
    "postgres-local": {
      "command": "docker",
      "args": [
        "run", "-i", "--rm",
        "--add-host=host.docker.internal:host-gateway",
        "-e", "DATABASE_URI",
        "crystaldba/postgres-mcp:latest",
        "--access-mode=restricted"
      ],
      "env": {
        "DATABASE_URI": "postgresql://postgres:postgres@host.docker.internal:5432/postgres"
      }
    },
    "elasticsearch-local": {
      "command": "docker",
      "args": [
        "run", "-i", "--rm",
        "--add-host=host.docker.internal:host-gateway",
        "-e", "ES_URL", "-e", "ES_USERNAME", "-e", "ES_PASSWORD",
        "docker.elastic.co/mcp/elasticsearch:latest",
        "stdio"
      ],
      "env": {
        "ES_URL": "http://host.docker.internal:9200",
        "ES_USERNAME": "elastic",
        "ES_PASSWORD": "elastic_local"
      }
    },
    "valkey-local": {
      "command": "docker",
      "args": [
        "run", "-i", "--rm",
        "--add-host=host.docker.internal:host-gateway",
        "-e", "REDIS_HOST", "-e", "REDIS_PORT", "-e", "REDIS_USERNAME", "-e", "REDIS_PWD",
        "mcp/redis:latest"
      ],
      "env": {
        "REDIS_HOST": "host.docker.internal",
        "REDIS_PORT": "6379",
        "REDIS_USERNAME": "valkey",
        "REDIS_PWD": "valkey_local"
      }
    },
    "qdrant-local": {
      "command": "docker",
      "args": [
        "run", "-i", "--rm",
        "--add-host=host.docker.internal:host-gateway",
        "-v", "cursor-qdrant-mcp-cache:/root/.cache",
        "-e", "QDRANT_URL", "-e", "QDRANT_API_KEY", "-e", "COLLECTION_NAME",
        "-e", "HF_HOME=/root/.cache/huggingface",
        "-e", "UV_CACHE_DIR=/root/.cache/uv",
        "ghcr.io/astral-sh/uv:python3.12-bookworm-slim",
        "uvx", "mcp-server-qdrant"
      ],
      "env": {
        "QDRANT_URL": "http://host.docker.internal:6333",
        "QDRANT_API_KEY": "qdrant_local",
        "COLLECTION_NAME": "mcp-local"
      }
    },
    "MCP_DOCKER": {
      "command": "docker",
      "args": ["mcp", "gateway", "run"]
    }
  }
}
```

</details>

<h2 id="external-compose">Другие контейнеры</h2>

Сеть **`databases_net`** — внешняя для вашего compose: `external: true`. Внутри сети хосты — DNS-имена сервисов, не `localhost`.

| Сервис | Хост | Порт |
|--------|------|------|
| PostgreSQL | `postgres` | 5432 |
| MongoDB | `mongodb` | 27017 |
| Valkey | `valkey` | 6379 |
| Elasticsearch | `elasticsearch` | 9200 |
| Qdrant | `qdrant` | 6333 |
| Kibana | `kibana` | 5601 |
| Redis Insight | `redisinsight` | 5540 |
| Портал | `portal` | 80 |

**Строки из контейнера в `databases_net`:**

```text
postgresql://postgres:postgres@postgres:5432/postgres
mongodb://admin:admin@mongodb:27017/?authSource=admin
http://elastic:elastic_local@elasticsearch:9200
redis://valkey:valkey_local@valkey:6379
http://qdrant:6333
```

Пример `docker-compose` приложения:

```yaml
services:
  app:
    image: your-image
    networks:
      - databases_net
    environment:
      DATABASE_URL: postgresql://postgres:postgres@postgres:5432/postgres
      MONGODB_URI: mongodb://admin:admin@mongodb:27017/?authSource=admin
      ELASTICSEARCH_URL: http://elastic:elastic_local@elasticsearch:9200
      REDIS_URL: redis://valkey:valkey_local@valkey:6379
      QDRANT_URL: http://qdrant:6333
      QDRANT_API_KEY: qdrant_local

networks:
  databases_net:
    external: true
```

```bash
docker run --rm -it --network databases_net your-image
```

---

<h2 id="db-local">Домен <code>db.local</code></h2>

Портал и админки — `http://db.local/` (порт 80). Без `db.local` СУБД с хоста доступны по `localhost` на своих портах; для Kibana/портала лучше сразу добавить запись.

`/etc/hosts` (Windows: `C:\Windows\System32\drivers\etc\hosts`):

```text
127.0.0.1 db.local
```

Занят порт 80 — в `.env` задайте `PORTAL_HOST_PORT=8080` и обновите `KIBANA_PUBLIC_URL` и `PORTAL_PUBLIC_ORIGIN` (например `http://db.local:8080` и `http://db.local:8080/kibana`).

---

<h2 id="web-portal">Портал (nginx)</h2>

Сервис **`portal`**: 80→80, WebSocket для pgAdmin/Kibana/mongo-express.

| С хоста (локально) | В сети `databases_net` |
|--------------------|------------------------|
| `http://db.local/` | `http://portal/` |
| `http://db.local/pgadmin/` | `http://portal/pgadmin/` |
| `http://db.local/mongo/` | `http://portal/mongo/` |
| `http://db.local/kibana/` | `http://portal/kibana/` |
| `http://db.local/valkey-insight/` (Basic **`insight`** / **`insight_local`**) | `http://portal/valkey-insight/` |
| `http://db.local:6333/dashboard` (`api-key` `qdrant_local`) | порт **6333** на хост, не через nginx :80 |

**Volumes UI:** pgAdmin → `pgadmin_data`; Kibana/ES → `es_data`; mongo-express — один URI в compose; Redis Insight → `redisinsight_data`, Basic в [`proxy/redisinsight.htpasswd`](proxy/redisinsight.htpasswd). В compose: `RITRUSTEDORIGINS=http://db.local`, `SERVER_PUBLICBASEURL=http://db.local/kibana` — открывать портал в браузере с того же хоста, что в этих переменных (локально).

---

## PostgreSQL

| | В сети | С хоста |
|--|--------|---------|
| Хост | `postgres` | `db.local` / `localhost` |
| Порт | 5432 | 5432 |
| User / DB / pass | `postgres` / `postgres` / `postgres` | то же |

```text
postgresql://postgres:postgres@postgres:5432/postgres
postgresql://postgres:postgres@db.local:5432/postgres
jdbc:postgresql://db.local:5432/postgres?user=postgres&password=postgres
jdbc:postgresql://postgres:5432/postgres?user=postgres&password=postgres
```

**pgAdmin:** `http://db.local/pgadmin/` — `admin@local.dev` / `admin`. Сервер: хост `postgres`, порт `5432`. Состояние — volume **`pgadmin_data`**. Внешний Postgres с pgAdmin: `host.docker.internal` или имя сервиса в общей сети.

---

## MongoDB

| | В сети | С хоста |
|--|--------|---------|
| Хост | `mongodb` | `db.local` / `localhost` |
| Порт | 27017 | 27017 |
| Учётка | `admin` / `admin`, authSource `admin` | то же |

```text
mongodb://admin:admin@mongodb:27017/?authSource=admin
mongodb://admin:admin@db.local:27017/?authSource=admin
```

**mongo-express:** `http://db.local/mongo/` — Basic `admin` / `admin`.

---

## Elasticsearch

X-Pack: Basic Auth, **`elastic`** / **`elastic_local`** (переменная `ELASTIC_PASSWORD` в [`docker-compose.yml`](docker-compose.yml)). Старый `es_data` без security → при ошибках: `docker compose down -v`, затем `up`.

**kibana_system** задаётся сервисом **`es-set-kibana-password`** (пароль **`kibana_local`** для Kibana → ES). Клиентам использовать **`elastic`**.

| Откуда | URL |
|--------|-----|
| Сеть | `http://elastic:elastic_local@elasticsearch:9200` |
| Хост | `http://elastic:elastic_local@db.local:9200` |

**Kibana:** `http://db.local/kibana/` — вход `elastic` / `elastic_local`. В контейнере: `http://kibana:5601/kibana/`.

<h2 id="database-logs-fluentd">Логи СУБД (Fluentd → Elasticsearch)</h2>

Сервис **`fluentd`** собирает **stdout/stderr** контейнеров PostgreSQL, MongoDB, Valkey и Qdrant и пишет их в **Elasticsearch** отдельными индексами (суточная ротация). Пароль к ES тот же, что у пользователя **`elastic`**: переменная **`ELASTIC_PASSWORD`** в **`.env`** (шаблон — [`.env.example`](.env.example)) и в [`docker-compose.yml`](docker-compose.yml).

### Имена индексов

Префиксы выбраны так, чтобы **не** совпадать со встроенным шаблоном Elastic для индексов `logs-*` (Fleet / Observability): иначе записи уходят в управляемые data streams и с ними неудобно работать вручную.

| СУБД | Шаблон индекса в Elasticsearch |
|------|--------------------------------|
| PostgreSQL | `db-logs-postgres-*` |
| MongoDB | `db-logs-mongodb-*` |
| Valkey | `db-logs-valkey-*` |
| Qdrant | `db-logs-qdrant-*` |

Пример полного имени: `db-logs-postgres-2026.04.17`.

### Просмотр в Kibana

1. Откройте **`http://db.local/kibana/`** (пользователь **`elastic`**, пароль из **`ELASTIC_PASSWORD`**, по умолчанию `elastic_local`).
2. **Stack Management** → **Data views** → **Create data view**.
3. Укажите имя (например `DB logs`) и **Index pattern**: `db-logs-*` — все четыре источника сразу, или отдельно `db-logs-postgres-*` и т.д.
4. Выберите поле времени **`@timestamp`** (если Kibana предложит выбор).
5. В **Discover** выберите созданное представление и фильтруйте по полям **`log`**, **`container_name`**, **`source`** (`stdout` / `stderr`).

Готовый **Data view** `db-logs-*` (имя **DB logs (all)**), runtime-поле **`db_kind`** (postgres / mongodb / valkey / qdrant), сохранённые поиски и дашборд **Local DB — log health** можно импортировать из [`kibana/db-logs-dashboard.ndjson`](kibana/db-logs-dashboard.ndjson): **Stack Management** → **Saved Objects** → **Import**, либо с хоста:

```bash
./kibana/import-dashboard.sh
```

Переменные: `KIBANA_URL` (по умолчанию `http://127.0.0.1/kibana`), `ELASTIC_USER` / `ELASTIC_PASSWORD`. После импорта откройте **Dashboard** → **Local DB — log health** (графики — классические Visualize; при необходимости их можно пересобрать в Lens в UI).

### Запросы в Dev Tools

**Management** → **Dev Tools** (или **Console** в зависимости от версии Kibana):

```http
GET db-logs-postgres-*/_search
{
  "size": 10,
  "sort": [{ "@timestamp": "desc" }]
}
```

С хоста (подставьте пароль из `.env`):

```bash
curl -s -u "elastic:${ELASTIC_PASSWORD:-elastic_local}" \
  "http://db.local:9200/db-logs-mongodb-*/_search?pretty&size=5"
```

### Как это устроено в Compose

- Образ и конфиг: каталог [`fluentd/`](fluentd/) ([`fluentd/Dockerfile`](fluentd/Dockerfile), [`fluentd/conf/fluent.conf`](fluentd/conf/fluent.conf)).
- Сервисы БД используют драйвер логирования **`fluentd`** и теги **`db.postgres`**, **`db.mongodb`**, **`db.valkey`**, **`db.qdrant`**.
- Адрес **`fluentd-address: 127.0.0.1:24224`**: логирование подключается **к демону Docker с хоста**, поэтому имя сервиса `fluentd` в этом адресе не работает; порт **24224** проброшен на **localhost** только у сервиса `fluentd`.
- СУБД стартуют после **готовности Fluentd** (healthcheck на порт 24224), чтобы первые строки лога не терялись.

---

## Qdrant

API и [UI](https://qdrant.tech/documentation/interfaces/web-ui/) на **6333**. **`QDRANT__SERVICE__API_KEY=qdrant_local`** — заголовок **`api-key`**.

```bash
curl -H "api-key: qdrant_local" http://db.local:6333/collections
```

| | Сеть | Хост |
|--|------|------|
| URL | `http://qdrant:6333` | `http://db.local:6333` |
| Ключ | `qdrant_local` | `qdrant_local` |

Данные — **`qdrant_data`**. Dashboard только на :6333, не за nginx :80.

---

## Valkey

[Valkey](https://valkey.io/), AOF + ACL: пользователь **`valkey`**, пароль **`valkey_local`**, `default` выключен. Не стартует после смены конфига — удалить **`valkey_data`**.

```text
redis://valkey:valkey_local@valkey:6379
redis://valkey:valkey_local@db.local:6379
```

Данные — **`valkey_data`**.

**Redis Insight:** `http://db.local/valkey-insight/` — Basic **`insight`** / **`insight_local`** ([`proxy/redisinsight.htpasswd`](proxy/redisinsight.htpasswd)). В UI: хост `valkey`, порт `6379`, user `valkey`, pass `valkey_local`. Настройки — **`redisinsight_data`**. Смена Basic: `htpasswd -nbB …` → тот же файл.

Прямой контейнер: `http://redisinsight:5540/valkey-insight/`.
