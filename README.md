# 🚀 B-Life Deployment & Infrastructure Repository

Centralized deployment automation, AWS CloudFormation infrastructure-as-code templates, configuration management, and deployment scripts for the **B-Life** platform.

---

## 🏛️ System Architecture

The infrastructure is designed for high availability, zero CORS overhead, strong security, and cost efficiency (eligible for AWS Free Tier).

```
                       [ Users / Mobile Browsers ]
                                    │
                                    │ HTTPS (Port 443)
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                     Amazon CloudFront CDN (Global)                     │
│                                                                        │
│   • Default Behavior (/*)                 • API Behaviors (/api/*)     │
│     → Serves SPA static assets              → Proxies directly to      │
│     → 403/404 rewritten to /index.html        Backend Origin           │
│     → Free SSL via CloudFront cert          → Eliminates CORS & mixed  │
│     → Origin Access Control (OAC)             content errors           │
└───────────────────┬─────────────────────────────────┬──────────────────┘
                    │                                 │
                    ▼                                 ▼
┌──────────────────────────────────────┐   ┌─────────────────────────────┐
│          Amazon S3 Bucket            │   │    AWS Elastic Beanstalk    │
│        (Frontend Web Assets)         │   │    Single-Instance (EC2)    │
│                                      │   │                             │
│ • Private bucket (Public access off) │   │ • Single t3.micro (Free)    │
│ • SSE-S3 AES-256 encryption          │   │ • Docker on Amazon Linux    │
│ • Incomplete multipart cleanup       │   │ • Zero ALB overhead ($0/mo) │
│ • Free tier eligible (5 GB)          │   │ • Least-Privilege IAM       │
└──────────────────────────────────────┘   └──────────────┬──────────────┘
                                                          │              │
                    ┌─────────────────────────────────────┘              │
                    ▼                                                    ▼
┌──────────────────────────────────────┐   ┌─────────────────────────────┐
│          Amazon S3 Bucket            │   │    Amazon RDS PostgreSQL    │
│            (Media Storage)           │   │         (Database)          │
│                                      │   │                             │
│ • Photos, audio, field attachments   │   │ • asyncpg Connection Pool   │
│ • CORS configured for PUT/GET        │   │ • SSL Enforced              │
│ • IAM instance profile permissions   │   │ • db.t3.micro (Free Tier)   │
└──────────────────────────────────────┘   └─────────────────────────────┘
```

---

## 📁 Repository Structure

```
BLife-deploy/
├── cloudformation.yaml                 # Consolidated master AWS CloudFormation template
├── parameters/
│   ├── parameters.prod.json.example    # Production parameter template
│   └── parameters.dev.json.example     # Development parameter template
├── scripts/
│   ├── deploy-infra.sh                 # CloudFormation stack provision / update (Bash)
│   ├── deploy-infra.ps1                # CloudFormation stack provision / update (PowerShell)
│   ├── deploy-backend.sh               # Backend Elastic Beanstalk deployment (Bash)
│   ├── deploy-backend.ps1              # Backend Elastic Beanstalk deployment (PowerShell)
│   ├── deploy-frontend.sh              # Frontend S3 build & CloudFront invalidation (Bash)
│   ├── deploy-frontend.ps1             # Frontend S3 build & CloudFront invalidation (PowerShell)
│   ├── teardown-infra.sh               # Stack teardown & deletion (Bash)
│   └── teardown-infra.ps1              # Stack teardown & deletion (PowerShell)
├── .gitignore                          # Ignores sensitive parameters & build archives
└── README.md                           # Central infrastructure & deployment manual
```

---

## ⚙️ CloudFormation Template Overview (`cloudformation.yaml`)

The template provisions all required AWS resources in an atomic stack:

| Resource Logical ID | AWS Service | Purpose |
| :--- | :--- | :--- |
| `FrontendBucket` | Amazon S3 | Private static website hosting for Vite/React SPA. |
| `CloudFrontOriginAccessControl` | Amazon CloudFront | OAC for secure, authenticated S3 bucket reads. |
| `MediaBucket` | Amazon S3 | Storage for field survey photos and audio. |
| `DBSecurityGroup` | Amazon EC2 | Restricts inbound port 5432 to VPC/backend instances. |
| `DatabaseInstance` | Amazon RDS | Managed PostgreSQL instance (`db.t3.micro`). |
| `BackendEC2Role` | AWS IAM | Grants S3 media access and CloudWatch logs permissions. |
| `BackendInstanceProfile` | AWS IAM | Associates IAM role to the Elastic Beanstalk EC2 instance. |
| `BackendApplication` | AWS Elastic Beanstalk | Application container for FastAPI backend. |
| `BackendConfigurationTemplate` | AWS Elastic Beanstalk | Docker platform configuration, environment vars, instance sizing. |
| `BackendEnvironment` | AWS Elastic Beanstalk | Single-instance running Docker on Amazon Linux 2023. |
| `CloudFrontDistribution` | Amazon CloudFront | Global CDN proxying `/*` to S3 and `/api/*`, `/health`, `/docs` to Beanstalk. |
| `FrontendBucketPolicy` | Amazon S3 | Grants CloudFront distribution access via OAC. |

---

## 🚀 Quickstart: Deploying Infrastructure

### 1. Prerequisites
- [AWS CLI v2](https://aws.amazon.com/cli/) installed and authenticated (`aws configure`).
- Target region configured (recommended: `ap-south-1` Sydney).
- Appropriate IAM permissions to provision S3, CloudFront, RDS, Beanstalk, and IAM roles (`CAPABILITY_NAMED_IAM`).

### 2. Configure Parameters
Copy the example parameter file and edit secrets:
```bash
cp parameters/parameters.prod.json.example parameters/parameters.prod.json
```
Update the parameters:
- `DBPassword`: A strong password for PostgreSQL.
- `BetterAuthSecret`: A secure random 32+ character key.
- `SolutionStackName`: Matching your target AWS region (defaults to `64bit Amazon Linux 2023 v4.14.1 running Docker`).

### 3. Deploy the Stack

#### Option A: Using Helper Scripts
**Linux / macOS / WSL:**
```bash
./scripts/deploy-infra.sh
```

**Windows PowerShell:**
```powershell
.\scripts\deploy-infra.ps1
```

#### Option B: Using AWS CLI Directly
```bash
aws cloudformation create-stack \
  --stack-name blife-prod \
  --template-body file://cloudformation.yaml \
  --parameters file://parameters/parameters.prod.json \
  --capabilities CAPABILITY_NAMED_IAM \
  --region ap-south-1
```

Wait for completion:
```bash
aws cloudformation wait stack-create-complete --stack-name blife-prod --region ap-south-1
```

Retrieve stack outputs:
```bash
aws cloudformation describe-stacks \
  --stack-name blife-prod \
  --region ap-south-1 \
  --query "Stacks[0].Outputs[*].[OutputKey, OutputValue]" \
  --output table
```

---

## 📦 Application Deployments

### 1. Deploying the Backend
You can deploy backend updates manually or via GitHub Actions in `BLife-Backend`:

**Using Script:**
```powershell
.\scripts\deploy-backend.ps1
```

**Manual AWS CLI:**
```bash
cd ../BLife-Backend

# Create deploy package
zip -r deploy.zip . \
  -x "*.git*" -x ".venv/*" -x "__pycache__/*" -x "*/__pycache__/*" -x "tests/*"

# Upload and deploy
S3_BUCKET=$(aws elasticbeanstalk create-storage-location --output text --query "S3Bucket" --region ap-south-1)
aws s3 cp deploy.zip "s3://${S3_BUCKET}/blife-backend/deploy-$(date +%s).zip"
aws elasticbeanstalk create-application-version \
  --application-name blife-backend \
  --version-label "v-$(date +%s)" \
  --source-bundle S3Bucket="${S3_BUCKET}",S3Key="blife-backend/deploy-$(date +%s).zip" \
  --region ap-south-1
aws elasticbeanstalk update-environment \
  --environment-name blife-backend-prod \
  --version-label "v-$(date +%s)" \
  --region ap-south-1
```

### 2. Deploying the Frontend
You can build and deploy the frontend SPA:

**Using Script:**
```powershell
.\scripts\deploy-frontend.ps1
```

**Manual AWS CLI:**
```bash
cd ../BLife-frontend
npm ci
npm run build

# Retrieve bucket & distribution from stack outputs
BUCKET_NAME=$(aws cloudformation describe-stacks --stack-name blife-prod --query "Stacks[0].Outputs[?OutputKey=='FrontendBucketName'].OutputValue" --output text --region ap-south-1)
CF_ID=$(aws cloudformation describe-stacks --stack-name blife-prod --query "Stacks[0].Outputs[?OutputKey=='CloudFrontDistributionId'].OutputValue" --output text --region ap-south-1)

# Sync build files
aws s3 sync dist/ "s3://${BUCKET_NAME}" --delete --region ap-south-1

# Invalidate cache
aws cloudfront create-invalidation --distribution-id "${CF_ID}" --paths "/*"
```

---

## 🗄️ Database Migrations

Run database migrations against the provisioned RDS instance:

```bash
cd ../BLife-Backend

# Retrieve DB connection string from stack output
DB_URL=$(aws cloudformation describe-stacks \
  --stack-name blife-prod \
  --region ap-south-1 \
  --query "Stacks[0].Outputs[?OutputKey=='DatabaseConnectionString'].OutputValue" \
  --output text)

# Run Alembic migrations
DATABASE_URL="${DB_URL}" uv run alembic upgrade head
```

---

## 🧹 Infrastructure Teardown

To tear down all resources and terminate the stack:

```powershell
.\scripts\teardown-infra.ps1 -StackName blife-prod
```
> [!CAUTION]
> Stack deletion will remove the RDS database and Elastic Beanstalk environment. S3 buckets containing files may require emptying before CloudFormation can delete them.

