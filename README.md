# postgres

Self-hosted Docker PostgreSQL instance shared across multiple apps. Each app gets its own database and owner role. Apps consume a single `DATABASE_URL`; this repo handles provisioning.

## Requirements

- Docker + Docker Compose
- bash + `openssl` (for the provisioning script — Windows users: WSL or Git Bash)

## Quickstart (local)

```bash
cp .env.example .env
# edit POSTGRES_PASSWORD to something strong
docker compose up -d
./scripts/add-app.sh myapp
```

Copy the printed `DATABASE_URL` into the app's `.env`.

## Adding an app

```bash
./scripts/add-app.sh myapp
```

Generates a random password, creates a database + owner user, and writes `apps/myapp.env`:

```
DATABASE_URL=postgres://myapp:<generated>@localhost:5432/myapp
DATABASE_URL_INTERNAL=postgres://myapp:<generated>@postgres:5432/myapp
```

- `DATABASE_URL` — apps running on the host (e.g. `pnpm dev`).
- `DATABASE_URL_INTERNAL` — app containers attached to the `shared-pg` Docker network.

`apps/<name>.env` is gitignored and mode 600 (on Unix-like filesystems).

## Removing an app

```bash
./scripts/remove-app.sh myapp
```

Drops the database, the user, and `apps/myapp.env`. Irreversible.

## VPS deployment

On the VPS:

```bash
git clone <this-repo> postgres
cd postgres
cp .env.example .env
# set a strong POSTGRES_PASSWORD
docker compose up -d
./scripts/add-app.sh <app>
```

For each app deployed on the VPS, in the app's own `docker-compose.yml` add the shared network:

```yaml
services:
  api:
    environment:
      DATABASE_URL: ${DATABASE_URL}   # set to the DATABASE_URL_INTERNAL value
    networks:
      - shared-pg

networks:
  shared-pg:
    external: true
```

The app's container resolves `postgres` via Docker DNS on the shared network.

## What's not here

- **Backups.** Out of scope. The simplest path when you need them: a cron job running `pg_dump` per database and shipping the output offsite (S3, B2). When backups become load-bearing, you've probably outgrown self-hosting — consider Supabase / Neon / RDS at that point.
- **Postgres extensions.** Add when needed by an app — build a custom image from `postgres:17-alpine`.
- **TLS to Postgres.** All traffic is on localhost or a private Docker network; no public exposure.
- **Connection pooling (PgBouncer).** Not needed at toy-app scale.

## Security notes

- The Postgres port is bound to `127.0.0.1:5432` only — never reachable from outside the host.
- Each app has its own owner role. A leaked credential can't read other apps' data.
- `.env` (superuser password) and `apps/*.env` (per-app credentials) are gitignored.
