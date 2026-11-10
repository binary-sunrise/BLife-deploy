#!/usr/bin/env bash
set -euo pipefail

STACK_NAME="${STACK_NAME:-blife-prod}"
REGION="${AWS_REGION:-ap-south-1}"

echo "=========================================================="
echo " CAUTION: TEARDOWN INFRASTRUCTURE"
echo " Stack: ${STACK_NAME}"
echo " Region: ${REGION}"
echo "=========================================================="
read -p "Are you sure you want to permanently delete stack '${STACK_NAME}'? (type 'yes' to proceed): " CONFIRM

if [ "${CONFIRM}" != "yes" ]; then
  echo "Aborted."
  exit 0
fi

echo "Deleting CloudFormation stack '${STACK_NAME}'..."
aws cloudformation delete-stack --stack-name "${STACK_NAME}" --region "${REGION}"

echo "Waiting for stack deletion to complete..."
aws cloudformation wait stack-delete-complete --stack-name "${STACK_NAME}" --region "${REGION}"

echo "✓ Stack '${STACK_NAME}' deleted successfully."

