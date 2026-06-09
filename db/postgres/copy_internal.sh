#!/usr/bin/env bash
# Usage: DB_USER=postgres DB_PASS=postgres DB_HOST=localhost DB_PORT=5432 OLD_DB_NAME=originalDbName NEW_DB_NAME=newDbName DROP_NEW_DB=true ./copy_internal.sh

# Variables
DB_USER="${DB_USER:?Variable not set or empty}"
DB_PASS="${DB_PASS:?Variable not set or empty}"
DB_HOST="${DB_HOST:?Variable not set or empty}"
DB_PORT="${DB_PORT:?Variable not set or empty}"
OLD_DB_NAME="${OLD_DB_NAME:?Variable not set or empty}"
NEW_DB_NAME="${NEW_DB_NAME:?Variable not set or empty}"
DROP_NEW_DB="${DROP_NEW_DB:-false}"

# Export PGPASSWORD so it can be used by psql
export PGPASSWORD=$DB_PASS

# Drop the new database if DROP_NEW_DB is set
if [ "$DROP_NEW_DB" = true ]; then
    psql -v ON_ERROR_STOP=1 -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -c "DROP DATABASE IF EXISTS $NEW_DB_NAME;"
fi

# Copy the database
psql -v ON_ERROR_STOP=1 -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -c "CREATE DATABASE $NEW_DB_NAME WITH TEMPLATE $OLD_DB_NAME OWNER $DB_USER;"