#!/usr/bin/env bash
set -ex
# Usage: DB_USER=postgres DB_PASS=postgres DB_HOST=localhost DB_PORT=5432 DB_NAME=dbName FILENAME=backup.sql.gz ABORT_ON_ERROR=false ./restore.sh

# Variables
DB_USER="${DB_USER:?Variable not set or empty}"
DB_PASS="${DB_PASS:?Variable not set or empty}"
DB_HOST="${DB_HOST:?Variable not set or empty}"
DB_PORT="${DB_PORT:?Variable not set or empty}"
DB_NAME="${DB_NAME:?Variable not set or empty}"
FILENAME="${FILENAME:?Variable not set or empty}"
ABORT_ON_ERROR="${ABORT_ON_ERROR:-false}"

# Get current date and time
current_date_time=$(date '+%Y-%m-%d_%H-%M')

# Export PGPASSWORD so it can be used by psql
export PGPASSWORD=$DB_PASS

# Drop the database if it exists and create a new one
{
  psql -v ON_ERROR_STOP=1 -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -c "DROP DATABASE IF EXISTS $DB_NAME;"
  psql -v ON_ERROR_STOP=1 -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -c "CREATE DATABASE $DB_NAME;"

  # Check if the file is gzip compressed
  if file "$FILENAME" | grep -q gzip; then
    # Restore the database from a gzipped SQL file
    if [ "$ABORT_ON_ERROR" = "true" ]; then
      gzip -dc "$FILENAME" | psql -v ON_ERROR_STOP=1 -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME"
    else
      gzip -dc "$FILENAME" | psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME"
    fi
  else
    # Restore the database from a non-gzipped SQL file
    if [ "$ABORT_ON_ERROR" = "true" ]; then
      psql -v ON_ERROR_STOP=1 -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$FILENAME"
    else
      psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$FILENAME"
    fi
  fi
} 2>&1 | tee "${current_date_time}_output.log"
