#!/usr/bin/env bash

EXECUTION_ARN="$1"
REGION="${2:-us-east-1}"
SLEEP_SECONDS="${3:-10}"

if [ -z "$EXECUTION_ARN" ]; then
  echo "Usage: $0 <execution-arn> [region] [sleep-seconds]"
  exit 1
fi

while true; do
  clear

  echo "============================================================"
  echo "Step Functions Execution Status"
  echo "============================================================"
  echo "Execution ARN: $EXECUTION_ARN"
  echo "Region:        $REGION"
  echo "Checked at:    $(date)"
  echo

  aws stepfunctions describe-execution \
    --execution-arn "$EXECUTION_ARN" \
    --region "$REGION" \
    --query '{
      status: status,
      startDate: startDate,
      stopDate: stopDate,
      name: name,
      stateMachineArn: stateMachineArn
    }' \
    --output table

  EXECUTION_STATUS=$(aws stepfunctions describe-execution \
    --execution-arn "$EXECUTION_ARN" \
    --region "$REGION" \
    --query 'status' \
    --output text)

  echo
  echo "============================================================"
  echo "Recent Execution Events"
  echo "============================================================"

  aws stepfunctions get-execution-history \
    --execution-arn "$EXECUTION_ARN" \
    --region "$REGION" \
    --max-results 25 \
    --reverse-order \
    --query 'events[].{
      id: id,
      timestamp: timestamp,
      type: type,
      state: stateEnteredEventDetails.name || stateExitedEventDetails.name || taskScheduledEventDetails.resource || taskStartedEventDetails.resource || taskSucceededEventDetails.resource || taskFailedEventDetails.resource,
      error: taskFailedEventDetails.error || executionFailedEventDetails.error || executionAbortedEventDetails.error,
      cause: taskFailedEventDetails.cause || executionFailedEventDetails.cause || executionAbortedEventDetails.cause
    }' \
    --output table

  echo
  echo "Current execution status: $EXECUTION_STATUS"

  case "$EXECUTION_STATUS" in
    SUCCEEDED|FAILED|TIMED_OUT|ABORTED)
      echo
      echo "Execution finished with status: $EXECUTION_STATUS"
      exit 0
      ;;
    RUNNING)
      echo "Still running. Checking again in ${SLEEP_SECONDS}s..."
      sleep "$SLEEP_SECONDS"
      ;;
    *)
      echo "Unknown or unexpected status: $EXECUTION_STATUS"
      sleep "$SLEEP_SECONDS"
      ;;
  esac
done
