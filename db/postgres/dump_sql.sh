#!/usr/bin/env bash

# Variables
DB_USER="${DB_USER:?Variable not set or empty}"
DB_PASS="${DB_PASS:?Variable not set or empty}"
DB_HOST="${DB_HOST:?Variable not set or empty}"
DB_PORT="${DB_PORT:?Variable not set or empty}"
DB_NAME="${DB_NAME:?Variable not set or empty}"
SCHEMA_DUMP_FILE="schema_${DB_NAME}.sql"
DATA_DUMP_FILE="data_${DB_NAME}.sql"
DB_DUMP_FILE="${DB_NAME}.sql"

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

# To restore PGPASSWORD=$DB_PASS pg_restore -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" "${DB_NAME}.dump"
dump_native() {
    DUMP_FILE="${DB_NAME}.dump"
    PGPASSWORD=$DB_PASS pg_dump -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" -Fc "$DB_NAME" -f "$DUMP_FILE"
    echo "Dumped to $DUMP_FILE (custom compressed format)"
}

# Parse command-line options
while getopts "sna" opt; do
  case ${opt} in
    s )
      dump_schema
      dump_data
      exit 0
      ;;
    n )
      dump_native
      exit 0
      ;;
    a )
      dump_all
      exit 0
      ;;
    \? )
      echo "Usage: cmd [-s] [-n] [-r]"
      exit 1
      ;;
  esac
done

# If no options were passed, dump everything
if [ $OPTIND -eq 1 ]; then
   echo "No options were passed. Everything will be dumped."
   dump_all
fi
