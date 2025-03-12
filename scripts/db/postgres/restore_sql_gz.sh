#!/usr/bin/env bash
set -ex
# set -ex for more debugging
# Required (Mac OS): brew install postgres pv pigz
# Usage: DB_USER=postgres DB_PASS=postgres DB_HOST=localhost DB_PORT=5432 DB_NAME=dbName FILENAME=backup.sql.gz ABORT_ON_ERROR=false ./restore.sh

# Variables
DB_USER="${DB_USER:?Variable not set or empty}"
DB_PASS="${DB_PASS:?Variable not set or empty}"
DB_HOST="${DB_HOST:?Variable not set or empty}"
DB_PORT="${DB_PORT:?Variable not set or empty}"
DB_NAME="${DB_NAME:?Variable not set or empty}"
FILENAME="${FILENAME:?Variable not set or empty}"
ABORT_ON_ERROR="${ABORT_ON_ERROR:-0}"

# Check if the file has a .gz extension
if [[ "$FILENAME" != *.gz ]]; then
  echo "Error: The file must have a .gz extension"
  exit 1
fi

# Get current date and time
current_date_time=$(date '+%Y-%m-%d_%H-%M')

# Export PGPASSWORD so it can be used by psql
export PGPASSWORD=$DB_PASS

# Drop the database if it exists and create a new one
{
  psql -v ON_ERROR_STOP=1 -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -c "DROP DATABASE IF EXISTS $DB_NAME;"
  psql -v ON_ERROR_STOP=1 -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -c "CREATE DATABASE $DB_NAME;"

  # Extract and execute role creation statements
  # Extract and create roles
  roles="rdsadmin root web_fdw_user"

  echo "$roles" | tr ' ' '\n' | while read -r role; do
    echo "Creating role: $role"
    psql -v ON_ERROR_STOP=1 -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -c "DO \$\$ BEGIN IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$role') THEN CREATE ROLE $role; END IF; END \$\$;"
  done
  echo "Roles created"

  # Restore the database from a gzipped SQL file
  ON_ERROR_STOP=$([ "$ABORT_ON_ERROR" = "true" ] && echo 1 || echo 0)
  echo "Will $( [ "$ABORT_ON_ERROR" = "true" ] && echo "abort" || echo "NOT abort" ) on error"
  # shellcheck disable=SC2086
  pv "$FILENAME" | pigz -dc | psql -v ON_ERROR_STOP=$ON_ERROR_STOP -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME"

  exit 0
} 2>&1 | tee "${DB_NAME}_${DB_PORT}_${FILENAME}_${current_date_time}.log"
