#!/usr/bin/env bash
set -euo pipefail

FRONTEND_DIR="${FRONTEND_DIR:-../BLife-frontend}"
STACK_NAME="${STACK_NAME:-blife-prod}"
REGION="${AWS_REGION:-ap-southeast-2}"

echo "=========================================================="
echo " Building & Deploying Frontend Application"
echo " Frontend Source: ${FRONTEND_DIR}"
echo " Stack: ${STACK_NAME}"
echo " Region: ${REGION}"
echo "=========================================================="

if [ ! -d "${FRONTEND_DIR}" ]; then
  echo "Error: Frontend directory '${FRONTEND_DIR}' does not exist."
  exit 1
fi

echo "1. Fetching stack outputs (Bucket & CloudFront ID)..."
FRONTEND_BUCKET=$(aws cloudformation describe-stacks \
  --stack-name "${STACK_NAME}" \
  --region "${REGION}" \
  --query "Stacks[0].Outputs[?OutputKey=='FrontendBucketName'].OutputValue" \
  --output text)

CF_ID=$(aws cloudformation describe-stacks \
  --stack-name "${STACK_NAME}" \
  --region "${REGION}" \
  --query "Stacks[0].Outputs[?OutputKey=='CloudFrontDistributionId'].OutputValue" \
  --output text)

echo "Frontend Bucket: ${FRONTEND_BUCKET}"
echo "CloudFront ID: ${CF_ID}"

echo "2. Building frontend application..."
(
  cd "${FRONTEND_DIR}"
  npm ci
  npm run build
)

echo "3. Syncing build artifacts to S3..."
aws s3 sync "${FRONTEND_DIR}/dist" "s3://${FRONTEND_BUCKET}" --delete --region "${REGION}"

echo "4. Invalidating CloudFront cache..."
aws cloudfront create-invalidation \
  --distribution-id "${CF_ID}" \
  --paths "/*" > /dev/null

echo "✓ Frontend deployment complete!"

