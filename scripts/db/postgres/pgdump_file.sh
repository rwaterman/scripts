#!/usr/bin/env bash
set -ex

# Variables
DB_USER="${DB_USER:?Variable not set or empty}"
DB_PASS="${DB_PASS:?Variable not set or empty}"
DB_HOST="${DB_HOST:?Variable not set or empty}"
DB_PORT="${DB_PORT:?Variable not set or empty}"
DB_NAME="${DB_NAME:?Variable not set or empty}"
SCHEMA_DUMP_FILE="schema_${DB_NAME}.sql"
SCHEMA_DUMP_GZ="schema_${DB_NAME}.sql.gz"
DATA_DUMP_FILE="data_${DB_NAME}.sql"
DATA_DUMP_GZ="data_${DB_NAME}.sql.gz"
DB_DUMP_FILE="${DB_NAME}.sql"
DB_DUMP_GZ="${DB_NAME}.sql.gz"

# Function to dump schema
dump_schema() {
    PGPASSWORD=$DB_PASS pg_dump -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" -s "$DB_NAME" > "$SCHEMA_DUMP_FILE"
    gzip -9 "$SCHEMA_DUMP_FILE"
}

# Function to dump data
dump_data() {
    PGPASSWORD=$DB_PASS pg_dump --inserts -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" -a "$DB_NAME" > "$DATA_DUMP_FILE"
    gzip -9 "$DATA_DUMP_FILE"
}

# Function to dump everything
dump_all() {
    PGPASSWORD=$DB_PASS pg_dump --inserts -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" "$DB_NAME" > "$DB_DUMP_FILE"
    gzip -9 "$DB_DUMP_FILE"
}

# Parse command-line options
while getopts "s" opt; do
  case ${opt} in
    s )
      dump_schema
      dump_data
      exit 0
      ;;
    \? ) echo "Usage: cmd [-s]"
      ;;
  esac
done

# If no options were passed, dump everything
if [ $OPTIND -eq 1 ]; then
   echo "No options were passed. Everything will be dumped."
   dump_all
fi
