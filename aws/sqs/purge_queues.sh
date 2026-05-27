#!/bin/bash
# Description: Purge AWS SQS queue messages. Supply SQS queue names in a comma-separated list.

# Usage: QUEUE_NAMES=queue-name-1,queue-name-2 ./purge-sqs-queues.sh
: "${QUEUE_NAMES:?Variable not set or empty}"

IFS=',' read -r -a QUEUE_ARRAY <<< "$QUEUE_NAMES"

if [ ${#QUEUE_ARRAY[@]} -eq 0 ]; then
  echo "No queues found to purge."
  exit 0
fi

purged_count=0

for QUEUE_NAME in "${QUEUE_ARRAY[@]}"; do
  QUEUE_URL=$(aws sqs get-queue-url --queue-name "$QUEUE_NAME" --query 'QueueUrl' --output text)
  if [ -n "$QUEUE_URL" ]; then
    echo "Purging queue: $QUEUE_NAME"
    aws sqs purge-queue --queue-url "$QUEUE_URL"
    ((purged_count++))
  else
    echo "Queue URL for $QUEUE_NAME not found."
  fi
done

if [ $purged_count -gt 0 ]; then
  echo "$purged_count queues purged."
else
  echo "No queues were purged."
fi
