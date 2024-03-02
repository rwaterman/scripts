#!/usr/bin/env bash
set -ex

# Ensure that the instance this task runs has at least the size of the uncompressed database + the gzip copy of the database

START_TIME=$(date '+%Y-%m-%d %H:%M:%S')

# Variables - DB
DB_USER="${DB_USER:?Variable not set or empty}"
DB_PASS="${DB_PASS:?Variable not set or empty}"
DB_HOST="${DB_HOST:?Variable not set or empty}"
DB_PORT="${DB_PORT:?Variable not set or empty}"
OLD_DB_NAME="${OLD_DB_NAME:?Variable not set or empty}"
NEW_DB_NAME="${NEW_DB_NAME:?Variable not set or empty}"
S3_BUCKET="${S3_BUCKET:-bckupsroa-new/tests}"
YYYY_MM_DD="${YYYY_MM_DD:?Variable not set or empty}"
SOURCE_STAGE="${SOURCE_STAGE:?Variable not set or empty}"
DEST_STAGE="${DEST_STAGE:?Variable not set or empty}"
PROD_RESTORE_OVERRIDE="${PROD_RESTORE_OVERRIDE:-false}" # Use this only when restoring a database TO production/main
# Variables - Performance
CONCURRENCY="${CONCURRENCY:-2}"

# Export PGPASSWORD so it can be used by psql
export PGPASSWORD=$DB_PASS

# Check if STAGE is production and PROD_RESTORE_OVERRIDE is not true
if [[ "$DEST_STAGE" == "main" && "$PROD_RESTORE_OVERRIDE" != "true" ]]; then
  echo "Error: Restoring a database to production without an PROD_RESTORE_OVERRIDE is not allowed."
  exit 1
fi

DB_RESTORE_PATH="restores/$DEST_STAGE/$YYYY_MM_DD"
mkdir -p "$DB_RESTORE_PATH"

# Restore the database from the directory of dump files in S3
aws s3 cp "s3://$S3_BUCKET/dumps/$SOURCE_STAGE/$YYYY_MM_DD/$OLD_DB_NAME.tar.xz" .
tar -xzf "$OLD_DB_NAME.tar.xz" -C "$DB_RESTORE_PATH"

psql -v ON_ERROR_STOP=1 -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -c "DROP DATABASE IF EXISTS $NEW_DB_NAME;"
psql -v ON_ERROR_STOP=1 -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -c "CREATE DATABASE $NEW_DB_NAME;"

pg_restore -v -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$NEW_DB_NAME" -Fd "$DB_RESTORE_PATH/$OLD_DB_NAME"

# Delete the local directory of dump files after restore
rm -r "$DB_RESTORE_PATH"

echo -e "$0\t$START_TIME\t$END_TIME" >> runtimes_pgrestore-dir.tsv
