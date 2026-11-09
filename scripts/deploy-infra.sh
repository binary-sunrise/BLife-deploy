#!/usr/bin/env bash
set -euo pipefail

# Configuration
STACK_NAME="${STACK_NAME:-blife-prod}"
REGION="${AWS_REGION:-ap-southeast-2}"
PARAM_FILE="${PARAM_FILE:-parameters/parameters.prod.json}"
TEMPLATE_FILE="cloudformation.yaml"

echo "=========================================================="
echo " AWS CloudFormation Deployment: ${STACK_NAME}"
echo " Region: ${REGION}"
echo " Template: ${TEMPLATE_FILE}"
echo " Parameters: ${PARAM_FILE}"
echo "=========================================================="

if [ ! -f "${PARAM_FILE}" ]; then
  echo "Error: Parameters file '${PARAM_FILE}' not found."
  echo "Copy an example file first: cp parameters/parameters.prod.json.example parameters/parameters.prod.json"
  exit 1
fi

echo "1. Validating CloudFormation template..."
aws cloudformation validate-template \
  --template-body "file://${TEMPLATE_FILE}" \
  --region "${REGION}" > /dev/null
echo "✓ Template is valid."

# Check if stack already exists
if aws cloudformation describe-stacks --stack-name "${STACK_NAME}" --region "${REGION}" >/dev/null 2>&1; then
  echo "2. Stack '${STACK_NAME}' exists. Creating Change Set..."
  CHANGE_SET_NAME="update-$(date +%s)"
  
  aws cloudformation create-change-set \
    --stack-name "${STACK_NAME}" \
    --change-set-name "${CHANGE_SET_NAME}" \
    --template-body "file://${TEMPLATE_FILE}" \
    --parameters "file://${PARAM_FILE}" \
    --capabilities CAPABILITY_NAMED_IAM \
    --region "${REGION}"

  echo "Waiting for Change Set creation..."
  aws cloudformation wait change-set-create-complete \
    --stack-name "${STACK_NAME}" \
    --change-set-name "${CHANGE_SET_NAME}" \
    --region "${REGION}"

  echo "Executing Change Set..."
  aws cloudformation execute-change-set \
    --stack-name "${STACK_NAME}" \
    --change-set-name "${CHANGE_SET_NAME}" \
    --region "${REGION}"

  echo "Waiting for stack update to complete..."
  aws cloudformation wait stack-update-complete \
    --stack-name "${STACK_NAME}" \
    --region "${REGION}"
  echo "✓ Stack update completed successfully."
else
  echo "2. Creating new stack '${STACK_NAME}'..."
  aws cloudformation create-stack \
    --stack-name "${STACK_NAME}" \
    --template-body "file://${TEMPLATE_FILE}" \
    --parameters "file://${PARAM_FILE}" \
    --capabilities CAPABILITY_NAMED_IAM \
    --region "${REGION}"

  echo "Waiting for stack creation to complete (this may take 10-15 minutes for RDS & CloudFront)..."
  aws cloudformation wait stack-create-complete \
    --stack-name "${STACK_NAME}" \
    --region "${REGION}"
  echo "✓ Stack creation completed successfully."
fi

echo ""
echo "==================== Stack Outputs ===================="
aws cloudformation describe-stacks \
  --stack-name "${STACK_NAME}" \
  --region "${REGION}" \
  --query "Stacks[0].Outputs[*].[OutputKey, OutputValue]" \
  --output table
echo "=========================================================="
