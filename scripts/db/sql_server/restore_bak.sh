#!/usr/bin/env bash

# Variables
DB_USER="${DB_USER:?Variable not set or empty}"
DB_PASS="${DB_PASS:?Variable not set or empty}"
DB_HOST="${DB_HOST:?Variable not set or empty}"
DB_PORT="${DB_PORT:?Variable not set or empty}"
DB_NAME="${DB_NAME:?Variable not set or empty}"
DB_DUMP_FILE="${DB_NAME}.bak"

# Function to dump everything
dump_all() {
    sqlcmd -S "$DB_HOST,$DB_PORT" -U "$DB_USER" -P "$DB_PASS" -Q "BACKUP DATABASE [$DB_NAME] TO DISK = N'$DB_DUMP_FILE' WITH NOFORMAT, NOINIT, NAME = '$DB_NAME-full', SKIP, NOREWIND, NOUNLOAD, STATS = 10"
}

# If no options were passed, dump everything
if [ $# -eq 0 ]; then
   echo "No options were passed. Everything will be dumped."
   dump_all
fi