#!/usr/bin/env bash
set -ex

START_TIME=$(date '+%Y-%m-%d %H:%M:%S')

STAGE="${STAGE:?Variable not set or empty}"

DB_USER="${DB_USER:?Variable not set or empty}"
DB_PASS="${DB_PASS:?Variable not set or empty}"
DB_HOST="${DB_HOST:?Variable not set or empty}"
DB_PORT="${DB_PORT:?Variable not set or empty}"
DB_NAME="${DB_NAME:?Variable not set or empty}"
S3_BUCKET="${S3_BUCKET:-bckupsroa-new/tests}"
DUMP_OPTION="both" # Default dump option

# Export PGPASSWORD so it can be used by psql
export PGPASSWORD=$DB_PASS

# Parse command line options for dump
while getopts "o:" opt; do
  case ${opt} in
    o )
      DUMP_OPTION=$OPTARG
      ;;
    \? ) echo "Usage: cmd [-o <migrations|seeds|both>]"
      exit 1
      ;;
  esac
done

# Validation of DUMP_OPTION
if [[ ! "migrations seeds both" =~ (^|[[:space:]])"$DUMP_OPTION"($|[[:space:]]) ]]; then
  echo "Invalid option for -o. Use one of 'migrations', 'seeds', or 'both'."
  exit 1
fi

# Get current date in yyyy-MM-DD format
YYYY_MM_DD=$(date '+%Y-%m-%d')

# Create a subdirectory for the stage with the current date
DB_DUMP_PATH="dumps/$STAGE/$YYYY_MM_DD"
rm -rf "$DB_DUMP_PATH"
mkdir -p "$DB_DUMP_PATH"

# Compress the directory of dump files and stream it to S3 using xz compression
echo "$DB_DUMP_PATH"/"$DB_NAME"

# Depending on DUMP_OPTION, perform the appropriate dump
case $DUMP_OPTION in
  migrations)
    echo "Dumping migrations..."
    # Placeholder for migrations dump logic
    ;;
  seeds)
    echo "Dumping seeds..."
    # Placeholder for seeds dump logic
    ;;
  both)
    echo "Dumping both migrations and seeds..."
    pg_dump -v -Z9 -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -Fd -f "$DB_DUMP_PATH/$DB_NAME"
    ;;
esac

tar -cJf "$DB_NAME.tar.xz" -C "$DB_DUMP_PATH" "$DB_NAME"
echo "File size: $(du -sh "$DB_NAME.tar.xz" | cut -f1)"
aws s3 cp "$DB_NAME.tar.xz" "s3://$S3_BUCKET/$DB_DUMP_PATH/$DB_NAME.tar.xz"
rm -r "$DB_DUMP_PATH"
rm "$DB_NAME.tar.xz"

# Get the end time
END_TIME=$(date '+%Y-%m-%d %H:%M:%S')

# Append the start and end times to a TSV file
echo -e "$0\t$START_TIME\t$END_TIME" >> runtimes_dump-dir.tsv

START_TIME_EPOCH=$(date -j -f "%Y-%m-%d %H:%M:%S" "$START_TIME" +%s)
END_TIME_EPOCH=$(date -j -f "%Y-%m-%d %H:%M:%S" "$END_TIME" +%s)
ELAPSED_TIME=$((END_TIME_EPOCH - START_TIME_EPOCH))

ELAPSED_HOURS=$((ELAPSED_TIME / 3600))
ELAPSED_MINUTES=$(( (ELAPSED_TIME / 60) % 60))
ELAPSED_SECONDS=$((ELAPSED_TIME % 60))

echo "Elapsed time: $ELAPSED_HOURS hours, $ELAPSED_MINUTES minutes, $ELAPSED_SECONDS seconds"

