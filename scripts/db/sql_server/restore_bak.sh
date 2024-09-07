#!/usr/bin/env bash

# Variables
DB_USER="${DB_USER:?Variable not set or empty}"
DB_PASS="${DB_PASS:?Variable not set or empty}"
DB_HOST="${DB_HOST:?Variable not set or empty}"
DB_PORT="${DB_PORT:?Variable not set or empty}"
DB_NAME="${DB_NAME:?Variable not set or empty}"
DB_FILENAME="${DB_FILENAME:?Variable not set or empty}"

# Function to check if database exists
check_db_exists() {
    result=$(sqlcmd -S "$DB_HOST,$DB_PORT" -U "$DB_USER" -P "$DB_PASS" -Q "SELECT db_id('$DB_NAME')" -h -1)
    if [ "$result" = "NULL" ]
    then
        return 1
    else
        return 0
    fi
}

# Function to create database
create_db() {
    sqlcmd -S "$DB_HOST,$DB_PORT" -U "$DB_USER" -P "$DB_PASS" -Q "CREATE DATABASE [$DB_NAME]"
}

# Function to restore database
restore_db() {
    sqlcmd -S "$DB_HOST,$DB_PORT" -U "$DB_USER" -P "$DB_PASS" -Q "RESTORE DATABASE [$DB_NAME] FROM DISK = N'$DB_FILENAME' WITH FILE = 1, NOUNLOAD, REPLACE, STATS = 10"
}

# If no options were passed, restore everything
if [ $# -eq 0 ]; then
   echo "No options were passed. Everything will be restored."
   if ! check_db_exists
   then
       echo "Database $DB_NAME does not exist. Creating..."
       create_db
       echo "Database $DB_NAME created."
   fi
   echo "Restoring database $DB_NAME from $DB_FILENAME..."
   restore_db
   echo "Database $DB_NAME restored from $DB_FILENAME"
fi