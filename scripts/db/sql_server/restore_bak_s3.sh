#!/usr/bin/env bash

# Variables
DB_USER="${DB_USER:?Variable not set or empty}"
DB_PASS="${DB_PASS:?Variable not set or empty}"
DB_HOST="${DB_HOST:?Variable not set or empty}"
DB_PORT="${DB_PORT:?Variable not set or empty}"
DB_NAME="${DB_NAME:?Variable not set or empty}"
S3_BUCKET="${S3_BUCKET:?Variable not set or empty}"
BAK_FILE="${BAK_FILE:?Variable not set or empty}"

# Function to restore database
restore_db() {
    sqlcmd -S "$DB_HOST,$DB_PORT" -U "$DB_USER" -P "$DB_PASS" -Q "EXEC msdb.dbo.rds_restore_database @restore_db_name='$DB_NAME', @s3_arn_to_restore_from='arn:aws:s3:::$S3_BUCKET/$BAK_FILE'"
}

# If no options were passed, restore everything
if [ $# -eq 0 ]; then
   echo "No options were passed. Everything will be restored."
   echo "Restoring database $DB_NAME from $BAK_FILE..."
   restore_db
   echo "Database $DB_NAME restored from $BAK_FILE"
fi