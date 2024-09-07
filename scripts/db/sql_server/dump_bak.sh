#!/usr/bin/env bash

# Variables
DB_USER="${DB_USER:?Variable not set or empty}"
DB_PASS="${DB_PASS:?Variable not set or empty}"
DB_HOST="${DB_HOST:?Variable not set or empty}"
DB_PORT="${DB_PORT:?Variable not set or empty}"
DB_NAME="${DB_NAME:?Variable not set or empty}"
DB_DUMP_FILE="${DB_NAME}.bak"

echo "Dumping database $DB_NAME to $DB_DUMP_FILE..."
sqlcmd -S "$DB_HOST,$DB_PORT" -U "$DB_USER" -P "$DB_PASS" -Q "BACKUP DATABASE [$DB_NAME] TO DISK = N'$DB_DUMP_FILE' WITH NOFORMAT, NOINIT, NAME = '$DB_NAME-full', SKIP, NOREWIND, NOUNLOAD, STATS = 10"
echo "Database $DB_NAME dumped to $DB_DUMP_FILE"
