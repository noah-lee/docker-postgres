#!/usr/bin/env bash
# add-app.sh — provision a database and owner role for an app.
#
# Usage: ./scripts/add-app.sh <app-name>
#
# Creates a Postgres user and database (user owns the database),
# then writes apps/<app-name>.env with the connection strings.

set -euo pipefail

APP_NAME="${1:-}"

if [ -z "$APP_NAME" ]; then
  echo "Usage: $0 <app-name>" >&2
  exit 1
fi

if [[ ! "$APP_NAME" =~ ^[a-z][a-z0-9_]*$ ]]; then
  echo "App name must match [a-z][a-z0-9_]* (lowercase, digits, underscores; must start with a letter)" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

if [ -f "$REPO_DIR/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  source "$REPO_DIR/.env"
  set +a
fi

POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"

PASSWORD="$(openssl rand -hex 16)"

echo "Provisioning database and user '$APP_NAME'..."

docker exec -i postgres psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d postgres <<SQL
CREATE USER "$APP_NAME" WITH ENCRYPTED PASSWORD '$PASSWORD';
CREATE DATABASE "$APP_NAME" OWNER "$APP_NAME";
SQL

mkdir -p "$REPO_DIR/apps"
ENV_FILE="$REPO_DIR/apps/$APP_NAME.env"

cat > "$ENV_FILE" <<EOF
# Generated $(date -u +"%Y-%m-%dT%H:%M:%SZ") by scripts/add-app.sh
# Copy the appropriate DATABASE_URL into $APP_NAME's .env.

# Local: app running on the same host as Postgres (e.g. \`pnpm dev\`).
DATABASE_URL=postgres://$APP_NAME:$PASSWORD@localhost:$POSTGRES_PORT/$APP_NAME

# Containerized: app running on the shared-pg Docker network (e.g. on the VPS).
DATABASE_URL_INTERNAL=postgres://$APP_NAME:$PASSWORD@postgres:5432/$APP_NAME
EOF

chmod 600 "$ENV_FILE" 2>/dev/null || true

echo
echo "Database '$APP_NAME' and user '$APP_NAME' created."
echo "Credentials written to $ENV_FILE"
echo
cat "$ENV_FILE"
