#!/usr/bin/env zsh

WORKGROUP_NAME="$1"

if [ -z "$WORKGROUP_NAME" ]; then
  echo "Usage: $0 <workgroup-name>"
  exit 1
fi

while true; do
  result=$(aws redshift-serverless get-workgroup \
    --workgroup-name "$WORKGROUP_NAME" \
    --query '[workgroup.status, workgroup.baseCapacity, workgroup.maxCapacity]' \
    --output text)

  read -r workgroup_status min_capacity max_capacity <<< "$result"

  echo "Status: $workgroup_status | Min capacity: $min_capacity | Max capacity: $max_capacity"

  if [ "$workgroup_status" = "AVAILABLE" ]; then
    break
  fi

  sleep 5
done
