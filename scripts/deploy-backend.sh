#!/usr/bin/env bash
set -euo pipefail

BACKEND_DIR="${BACKEND_DIR:-../BLife-Backend}"
REGION="${AWS_REGION:-ap-southeast-2}"
APP_NAME="${APP_NAME:-blife-backend}"
ENV_NAME="${ENV_NAME:-blife-backend-prod}"

echo "=========================================================="
echo " Packaging & Deploying Backend Application"
echo " Backend Source: ${BACKEND_DIR}"
echo " Elastic Beanstalk App: ${APP_NAME}"
echo " Elastic Beanstalk Env: ${ENV_NAME}"
echo " Region: ${REGION}"
echo "=========================================================="

if [ ! -d "${BACKEND_DIR}" ]; then
  echo "Error: Backend directory '${BACKEND_DIR}' does not exist."
  exit 1
fi

TEMP_ZIP="$(pwd)/deploy-backend.zip"
rm -f "${TEMP_ZIP}"

echo "1. Generating deployment package..."
(
  cd "${BACKEND_DIR}"
  zip -r "${TEMP_ZIP}" . \
    -x "*.git*" \
    -x ".venv/*" \
    -x "__pycache__/*" \
    -x "*/__pycache__/*" \
    -x "tests/*" \
    -x ".pytest_cache/*" \
    -x ".ruff_cache/*" \
    -x ".mypy_cache/*"
)

VERSION_LABEL="backend-$(date +%s)"
echo "2. Querying Elastic Beanstalk S3 storage location..."
S3_BUCKET=$(aws elasticbeanstalk create-storage-location --region "${REGION}" --output text --query "S3Bucket")
S3_KEY="${APP_NAME}/${VERSION_LABEL}.zip"

echo "3. Uploading ${TEMP_ZIP} to s3://${S3_BUCKET}/${S3_KEY}..."
aws s3 cp "${TEMP_ZIP}" "s3://${S3_BUCKET}/${S3_KEY}" --region "${REGION}"
rm -f "${TEMP_ZIP}"

echo "4. Creating application version '${VERSION_LABEL}'..."
aws elasticbeanstalk create-application-version \
  --application-name "${APP_NAME}" \
  --version-label "${VERSION_LABEL}" \
  --source-bundle S3Bucket="${S3_BUCKET}",S3Key="${S3_KEY}" \
  --region "${REGION}"

echo "5. Updating environment '${ENV_NAME}'..."
aws elasticbeanstalk update-environment \
  --environment-name "${ENV_NAME}" \
  --version-label "${VERSION_LABEL}" \
  --region "${REGION}"

echo "Waiting for environment update to finish..."
aws elasticbeanstalk wait environment-updated \
  --environment-name "${ENV_NAME}" \
  --region "${REGION}"

echo "✓ Backend deployment complete!"

