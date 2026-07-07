#!/usr/bin/env bash
# remove-app.sh — drop a database and its owner role.
#
# Usage: ./scripts/remove-app.sh <app-name>

set -euo pipefail

APP_NAME="${1:-}"

if [ -z "$APP_NAME" ]; then
  echo "Usage: $0 <app-name>" >&2
  exit 1
fi

if [[ ! "$APP_NAME" =~ ^[a-z][a-z0-9_]*$ ]]; then
  echo "App name must match [a-z][a-z0-9_]*" >&2
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

read -r -p "Drop database '$APP_NAME' and user '$APP_NAME'? This is irreversible. [y/N] " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
  echo "Aborted."
  exit 0
fi

docker exec -i postgres psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d postgres <<SQL
DROP DATABASE IF EXISTS "$APP_NAME";
DROP USER IF EXISTS "$APP_NAME";
SQL

ENV_FILE="$REPO_DIR/apps/$APP_NAME.env"
if [ -f "$ENV_FILE" ]; then
  rm "$ENV_FILE"
  echo "Removed $ENV_FILE"
fi

echo "Database '$APP_NAME' and user '$APP_NAME' dropped."
