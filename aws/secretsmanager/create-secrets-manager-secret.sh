#!/bin/bash

# Usage:
# ./create-secret.sh my-secret-name secret-value.json us-west-2

# Input parameters
SECRET_NAME=$1
SECRET_FILE=$2
AWS_REGION=$3

# Validate input
if [[ -z "$SECRET_NAME" || -z "$SECRET_FILE" || -z "$AWS_REGION" ]]; then
    echo "Usage: $0 <secret-name> <secret-json-file> <aws-region>"
    exit 1
fi

if [[ ! -f "$SECRET_FILE" ]]; then
    echo "Error: Secret JSON file '$SECRET_FILE' does not exist."
    exit 1
fi

# Read the JSON file content
SECRET_STRING=$(cat "$SECRET_FILE")

# Create the secret
aws secretsmanager create-secret \
    --name "$SECRET_NAME" \
    --secret-string "$SECRET_STRING" \
    --region "$AWS_REGION"

# Check result
if [[ $? -eq 0 ]]; then
    echo "Secret '$SECRET_NAME' created successfully in region '$AWS_REGION'."
else
    echo "Failed to create secret."
    exit 1
fi
