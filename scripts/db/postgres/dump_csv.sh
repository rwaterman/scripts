#!/usr/bin/env bash
# Variables
DB_USER="${DB_USER:?Variable not set or empty}"
DB_PASS="${DB_PASS:?Variable not set or empty}"
DB_HOST="${DB_HOST:?Variable not set or empty}"
DB_PORT="${DB_PORT:?Variable not set or empty}"
DB_NAME="${DB_NAME:?Variable not set or empty}"
SCHEMA_NAME="public"

# Connect to PostgreSQL
export PGPASSWORD=$DB_PASS
psql -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -c "\dt" | awk 'NR>3 {print $3}' | sed '$d' | sed '$d' > tables.txt

# Dump each table to a separate CSV file
while read -r table; do
    TABLE_CSV="${table}.csv"
    psql -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -c "\COPY (SELECT * FROM ${DB_NAME}.${SCHEMA_NAME}.\"$table\") TO STDOUT WITH CSV HEADER" > "$TABLE_CSV"
done < tables.txt

# Clean up
unset PGPASSWORD