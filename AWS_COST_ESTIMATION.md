# 📊 AWS Cost Estimation & Architecture Tiering Analysis
**Project:** B-Life (Vasudha Biodiversity Observation Platform) — KFRI  
**Region:** Asia Pacific (Mumbai) `ap-south-1`  
**Infrastructure Code:** [`cloudformation.yaml`](file:///d:/Veena/KFRI/BLife-deploy/cloudformation.yaml)  
**Date of Estimation:** November 2026  
**Pricing Currency:** USD ($) & INR (₹) *(Estimated conversion: 1 USD ≈ 86 INR)*

---

## 1. Executive Summary & Architecture Context

The infrastructure defined in [`cloudformation.yaml`](file:///d:/Veena/KFRI/BLife-deploy/cloudformation.yaml) implements a modern, decoupled cloud architecture designed to eliminate unnecessary AWS overhead while supporting the FastAPI backend, React/Vite SPA frontend, and media storage for biodiversity field surveys.

### Architectural Blueprint

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
│        (Frontend Web Assets)         │   │    Docker Platform (AL2023) │
│                                      │   │                             │
│ • Private bucket (Public access off) │   │ • SingleInstance / ALB      │
│ • SSE-S3 AES-256 encryption          │   │ • FastAPI Python 3.11/3.12  │
│ • Incomplete multipart cleanup       │   │ • Zero ALB overhead in T1/T2│
│ • Free tier eligible (5 GB)          │   │ • Least-Privilege IAM       │
└──────────────────────────────────────┘   └──────────────┬──────────────┘
                                                          │              │
                    ┌─────────────────────────────────────┘              │
                    ▼                                                    ▼
┌──────────────────────────────────────┐   ┌─────────────────────────────┐
│          Amazon S3 Bucket            │   │    Amazon RDS PostgreSQL    │
│            (Media Storage)           │   │         (Database)          │
│                                      │   │                             │
│ • Photos, audio, field attachments   │   │ • PostgreSQL 16 on gp3 SSD  │
│ • CORS configured for PUT/GET        │   │ • SSL Enforced Encryption   │
│ • IAM instance profile permissions   │   │ • Single-AZ or Multi-AZ     │
└──────────────────────────────────────┘   └─────────────────────────────┘
```

### Key Cost Innovations in the Architecture

1. **Elimination of Application Load Balancer (ALB) for Basic & Standard Tiers:**  
   Standard AWS reference architectures deploy an ALB costing **~$18.00–$22.50/month** in base charges even with zero traffic. The CloudFormation template configures `EnvironmentType: SingleInstance` in Elastic Beanstalk and routes `/api/*` through CloudFront, **saving over $240/year**.
2. **Consolidated Edge Routing via CloudFront:**  
   CloudFront provides global CDN caching, SSL termination, and reverse proxying under a single domain. It eliminates cross-origin resource sharing (CORS) preflight penalties and operates within the generous AWS Always-Free Tier (1 TB data transfer + 10M requests free per month).
3. **AWS Free Tier Maximization:**  
   For the first 12 months, Tier 1 runs within AWS Free Tier limits (750 hours EC2 `t3.micro`, 750 hours RDS `db.t3.micro`, 20 GB database storage, 5 GB S3).
4. **Transparent Accounting for Modern AWS Charges:**  
   Accounts for the mandatory AWS public IPv4 address fee ($0.005/hour = $3.65/month) introduced in 2024 for EC2 single instances with public IPs.

---

## 2. Service-by-Service CloudFormation Resource Mapping

| Resource in `cloudformation.yaml` | AWS Service | Billable Configuration Metric | Cost Factor |
| :--- | :--- | :--- | :--- |
| `FrontendBucket` | **Amazon S3** | S3 Standard Storage (GB-mo), GET/PUT requests | ~$0.025 / GB-month; Free Tier 5 GB |
| `MediaBucket` | **Amazon S3** | S3 Standard / Intelligent-Tiering Storage (GB-mo) | ~$0.025 / GB-month + PUT/GET calls |
| `CloudFrontDistribution` | **Amazon CloudFront** | Data Transfer Out (GB), HTTP/HTTPS requests | First 1 TB/mo free; $0.085–$0.120/GB beyond |
| `CloudFrontOriginAccessControl` | **Amazon CloudFront** | OAC feature | Free |
| `BackendApplication` & `BackendEnvironment` | **AWS Elastic Beanstalk** | Service orchestration fee | **$0.00** (Beanstalk is free; pay only for underlying EC2/EBS) |
| Beanstalk Compute Instance | **Amazon EC2** | Instance hours (`t3.micro`, `t3.small`, `t3.medium`) | $0.0104 to $0.0416 / hr in `ap-south-1` |
| Beanstalk Root Volume | **Amazon EBS** | General Purpose SSD (`gp3`) volume size (GB-mo) | $0.0912 / GB-month |
| Public IPv4 Address | **Amazon VPC / EC2** | In-use public IPv4 address hours | $0.005 / hour ($3.65 / month) |
| `DatabaseInstance` | **Amazon RDS PostgreSQL** | Instance hours (`db.t3.micro` to `db.t3.medium`) | $0.025 to $0.098 / hr (Single-AZ) |
| Database Storage | **Amazon RDS gp3** | Allocated SSD storage (GB-mo) | $0.115 / GB-month (Single-AZ); $0.230 (Multi-AZ) |
| Automated DB Backups | **Amazon RDS** | Backup storage beyond 100% of DB size | Free up to allocated size; $0.095/GB beyond |
| `DBSecurityGroup` | **Amazon EC2 / VPC** | VPC Security Groups & Network Interfaces | Free |
| `BackendEC2Role` & Profiles | **AWS IAM** | Roles, Policies, Instance Profiles | Free |
| `DeployerUser` & OIDC | **AWS IAM / STS** | IAM Users, Access Keys, GitHub OIDC Provider | Free |
| *(T3/T4 Upgrades)* ALB | **Elastic Load Balancing** | Hourly base fee + Load Balancer Capacity Units (LCU) | ~$16.43/mo base + $0.008/LCU-hour |
| *(T4 Upgrade)* WAF | **AWS WAF** | WebACL ($5/mo) + Rules ($1/rule/mo) + Requests ($0.60/1M) | ~$9.00 - $15.00/mo |

---

## 3. Detailed Cost Estimates Across 4 Tiers

---

### Tier 1: Basic / Free-Tier Friendly (Dev, PoC & Field Pilot)

**Workload Profile:** Development, proof of concept, academic demonstrations, or initial pilot deployments with 1–20 concurrent users. Directly mirrors default template values.

#### 1. Configuration Details
- **Architecture Mode:** Elastic Beanstalk `SingleInstance` (No Load Balancer).
- **Backend Compute:** 1 x `t3.micro` (2 vCPU, 1 GiB RAM, burstable).
- **Compute Storage:** 20 GB `gp3` root EBS volume.
- **Networking:** 1 x Public IPv4 address assigned to the single instance.
- **Database:** Amazon RDS PostgreSQL 16, `db.t3.micro` (2 vCPU, 1 GiB RAM), Single-AZ.
- **Database Storage:** 20 GB `gp3` SSD storage + 7 days automated backups.
- **Object Storage:**
  - `FrontendBucket`: 5 GB (React/Vite static build bundle).
  - `MediaBucket`: 5 GB (initial test photos, audio files).
- **CDN:** CloudFront `PriceClass_100` (US, Canada, Europe edge; routes globally), Free default SSL certificate.
- **Monitoring & CI/CD:** Basic CloudWatch (5-min metrics), GitHub Actions OIDC integration.

#### 2. Pricing Breakdown

| Component | AWS Resource Details | Monthly Cost (Free Tier Active) | Monthly Cost (Standard On-Demand) | Annual Cost (On-Demand) |
| :--- | :--- | :---: | :---: | :---: |
| **Backend Compute** | 1x `t3.micro` Linux (730 hrs) | $0.00 *(750 hrs free)* | $7.59 | $91.10 |
| **Compute Storage** | 20 GB `gp3` EBS volume | $0.00 *(30 GB free)* | $1.82 | $21.89 |
| **Public IPv4** | 1x In-use Public IPv4 address (730 hrs) | $3.65 | $3.65 | $43.80 |
| **Database Compute** | 1x `db.t3.micro` Single-AZ (730 hrs) | $0.00 *(750 hrs free)* | $18.25 | $219.00 |
| **Database Storage** | 20 GB `gp3` RDS storage | $0.00 *(20 GB free)* | $2.30 | $27.60 |
| **Database Backups** | 7-day automated backups (<20 GB) | $0.00 *(100% free)* | $0.00 | $0.00 |
| **Frontend Storage** | 5 GB S3 Standard Storage + Requests | $0.00 *(5 GB free)* | $0.13 | $1.50 |
| **Media Storage** | 5 GB S3 Standard Storage + Requests | $0.00 *(5 GB free)* | $0.13 | $1.50 |
| **CDN / CloudFront** | 50 GB Data Transfer Out + 100k requests | $0.00 *(1 TB free)* | $0.00 | $0.00 |
| **IAM & CI/CD** | IAM Roles, OIDC, Deployer User | $0.00 | $0.00 | $0.00 |
| **Total (USD)** | | **$3.65 / mo** | **$33.87 / mo** | **$406.40 / yr** |
| **Total (INR @ ₹86)** | | **₹314 / mo** | **₹2,913 / mo** | **₹34,950 / yr** |

> [!NOTE]
> During the first 12 months with AWS Free Tier, the total out-of-pocket cost is only **$3.65/month** (representing the standard public IPv4 address fee). After the 12-month Free Tier period, standard on-demand pricing applies at **~$33.87/month**.

---

### Tier 2: Standard (Small Production & Departmental Deployment)

**Workload Profile:** Production deployment for KFRI researchers, forestry staff, and field surveyors. Handles 50–200 daily active users, continuous photo uploads, and database queries without memory starvation.

#### 1. Configuration Details
- **Architecture Mode:** Elastic Beanstalk `SingleInstance` (Cost-optimized, no ALB overhead).
- **Backend Compute:** 1 x `t3.small` (2 vCPU, 2 GiB RAM) — provides sufficient memory headroom for FastAPI async workers and image thumbnail processing.
- **Compute Storage:** 30 GB `gp3` root EBS volume.
- **Networking:** 1 x Public IPv4 address assigned to the instance.
- **Database:** Amazon RDS PostgreSQL 16, `db.t3.small` (2 vCPU, 2 GiB RAM), Single-AZ.
- **Database Storage:** 50 GB `gp3` SSD storage + 7 days automated backups.
- **Object Storage:**
  - `FrontendBucket`: 5 GB static assets.
  - `MediaBucket`: 50 GB field photos and survey data.
- **CDN:** CloudFront `PriceClass_200` (includes edge caching locations across India / Asia Pacific, Middle East, Europe, North America) + custom domain with free AWS ACM SSL certificate.
- **Monitoring & CI/CD:** Basic CloudWatch + 2 GB application logs ingestion.

#### 2. Pricing Breakdown

| Component | AWS Resource Details | Monthly Cost (USD) | Annual Cost (USD) | Monthly Cost (INR @ ₹86) |
| :--- | :--- | :---: | :---: | :---: |
| **Backend Compute** | 1x `t3.small` Linux (730 hrs @ $0.0208/hr) | $15.18 | $182.21 | ₹1,305 |
| **Compute Storage** | 30 GB `gp3` EBS root volume (@ $0.0912/GB) | $2.74 | $32.83 | ₹236 |
| **Public IPv4** | 1x In-use Public IPv4 address (730 hrs) | $3.65 | $43.80 | ₹314 |
| **Database Compute** | 1x `db.t3.small` Single-AZ (730 hrs @ $0.049/hr) | $35.77 | $429.24 | ₹3,076 |
| **Database Storage** | 50 GB `gp3` RDS storage (@ $0.115/GB) | $5.75 | $69.00 | ₹495 |
| **Database Backups** | 7-day automated backups (<50 GB) | $0.00 | $0.00 | ₹0 |
| **Frontend Storage** | 5 GB S3 Standard Storage + Requests | $0.13 | $1.50 | ₹11 |
| **Media Storage** | 50 GB S3 Standard Storage + 50k PUT/GET | $1.25 | $15.00 | ₹108 |
| **CDN / CloudFront** | PriceClass_200, 100 GB Data Out + 500k reqs | $1.50 | $18.00 | ₹129 |
| **DNS & SSL** | Route 53 Hosted Zone + ACM Public SSL | $0.50 | $6.00 | ₹43 |
| **CloudWatch Logs** | 2 GB ingestion & storage | $1.00 | $12.00 | ₹86 |
| **Total** | | **$67.47 / mo** | **$809.58 / yr** | **₹5,802 / mo** |

> [!TIP]
> **Graviton Optimization:** Switching from Intel `t3` to ARM-based AWS Graviton2 (`t4g.small` and `db.t4g.small`), which is fully supported by Docker and Python, reduces the monthly total from **$67.47** down to **~$58.50/month** (~13% additional savings with superior performance).

---

### Tier 3: Production (Institutional Rollout, Auto-Scaling & Load Balanced)

**Workload Profile:** Public-facing institutional portal for statewide biodiversity observations, high concurrent user surges, zero-downtime rolling application deployments, and enhanced reliability.

#### 1. Configuration Details
- **Architecture Mode:** Elastic Beanstalk `LoadBalanced` with Application Load Balancer (ALB) across 2 Availability Zones.
- **Backend Compute:** Auto-Scaling Group with **Min: 2, Max: 4** x `t3.small` (2 vCPU, 2 GiB RAM each) distributed across 2 AZs. Instances are in private subnets behind the ALB (eliminates individual public IPv4 fees).
- **Compute Storage:** 2 x 30 GB `gp3` EBS volumes (60 GB total baseline).
- **Load Balancer:** AWS Application Load Balancer (ALB) managing health checks, path routing, and SSL offloading.
- **Database:** Amazon RDS PostgreSQL 16, `db.t3.medium` (2 vCPU, 4 GiB RAM), Single-AZ with automated daily snapshots + 14-day retention.
- **Database Storage:** 100 GB `gp3` SSD storage (3,000 baseline IOPS, 125 MB/s throughput).
- **Object Storage:**
  - `FrontendBucket`: 10 GB static assets & versioning.
  - `MediaBucket`: 200 GB field photos/audio with S3 Standard-IA lifecycle transitions for assets older than 90 days.
- **CDN:** CloudFront `PriceClass_200`, custom domain, ACM SSL, HTTP/2 & HTTP/3 enabled.
- **Monitoring & CI/CD:** Detailed CloudWatch metrics (1-min intervals), alarms, and Route 53 DNS routing.

#### 2. Pricing Breakdown

| Component | AWS Resource Details | Monthly Cost (USD) | Annual Cost (USD) | Monthly Cost (INR @ ₹86) |
| :--- | :--- | :---: | :---: | :---: |
| **Backend Compute** | 2x `t3.small` Linux baseline (1,460 hrs) | $30.37 | $364.42 | ₹2,612 |
| **Compute Storage** | 2x 30 GB `gp3` EBS volumes (60 GB total) | $5.47 | $65.66 | ₹470 |
| **Application Load Balancer** | 1x ALB (730 hrs @ $0.0225/hr + 1 LCU) | $22.27 | $267.18 | ₹1,915 |
| **Database Compute** | 1x `db.t3.medium` Single-AZ (730 hrs @ $0.098/hr) | $71.54 | $858.48 | ₹6,152 |
| **Database Storage** | 100 GB `gp3` RDS storage (@ $0.115/GB) | $11.50 | $138.00 | ₹989 |
| **Database Backups** | 14-day backup retention (~100 GB backup storage) | $0.00 *(Included)* | $0.00 | ₹0 |
| **Frontend Storage** | 10 GB S3 Standard Storage + Requests | $0.25 | $3.00 | ₹22 |
| **Media Storage** | 200 GB S3 Storage (Standard + IA blend) | $5.00 | $60.00 | ₹430 |
| **CDN / CloudFront** | 300 GB Data Out + 2M requests | $4.00 | $48.00 | ₹344 |
| **DNS & Domains** | Route 53 Hosted Zone + Query fees | $0.50 | $6.00 | ₹43 |
| **CloudWatch & Alarms** | 10 GB logs ingestion + 5 alarms | $5.00 | $60.00 | ₹430 |
| **Total** | | **$155.90 / mo** | **$1,870.74 / yr** | **₹13,407 / mo** |

---

### Tier 4: High Availability & Enterprise (Mission-Critical & Multi-AZ Disaster Resilient)

**Workload Profile:** Critical production infrastructure, state-wide government portal with strict SLA requirements (>99.95% uptime), real-time high-throughput mobile telemetry, automated failover, and comprehensive web application security.

#### 1. Configuration Details
- **Architecture Mode:** Elastic Beanstalk `LoadBalanced` across 3 Availability Zones with strict Multi-AZ fault tolerance.
- **Backend Compute:** Auto-Scaling Group with **Min: 2, Max: 6** x `t3.medium` (2 vCPU, 4 GiB RAM each) distributed across multiple AZs.
- **Compute Storage:** 2 x 50 GB `gp3` EBS volumes (100 GB total baseline).
- **Load Balancer:** Multi-AZ Application Load Balancer with connection draining, sticky sessions, and TLS 1.3 enforcement.
- **Database (Multi-AZ):** Amazon RDS PostgreSQL 16, `db.t3.medium` **Multi-AZ** (Synchronous standby replica in a secondary AZ with automated zero-data-loss failover in <60 seconds).
- **Database Storage:** 250 GB `gp3` Multi-AZ SSD storage + 30 days point-in-time recovery (PITR).
- **Object Storage:**
  - `FrontendBucket`: 20 GB versioned static web assets.
  - `MediaBucket`: 500 GB media storage with S3 Intelligent-Tiering (automatically moving inactive images to archive tiers).
- **Edge Security & CDN:** CloudFront `PriceClass_All` (Global) + **AWS WAF** (Web Application Firewall) protecting against SQL injection, cross-site scripting (XSS), and automated bots.
- **Monitoring & Observability:** AWS CloudWatch Logs, Container Insights, Metric Alarms, and SNS alerts.

#### 2. Pricing Breakdown

| Component | AWS Resource Details | Monthly Cost (USD) | Annual Cost (USD) | Monthly Cost (INR @ ₹86) |
| :--- | :--- | :---: | :---: | :---: |
| **Backend Compute** | 2x `t3.medium` Linux baseline (1,460 hrs) | $60.74 | $728.83 | ₹5,224 |
| **Compute Storage** | 2x 50 GB `gp3` EBS volumes (100 GB total) | $9.12 | $109.44 | ₹784 |
| **Application Load Balancer** | 1x Multi-AZ ALB (730 hrs + 2 LCUs) | $28.11 | $337.26 | ₹2,417 |
| **Database Compute** | 1x `db.t3.medium` **Multi-AZ** (730 hrs @ $0.196/hr) | $143.08 | $1,716.96 | ₹12,305 |
| **Database Storage** | 250 GB `gp3` Multi-AZ storage (@ $0.230/GB) | $57.50 | $690.00 | ₹4,945 |
| **Database Backups** | 30-day retention & cross-AZ snapshots | $4.75 | $57.00 | ₹409 |
| **Frontend Storage** | 20 GB S3 Standard Storage + Versioning | $0.50 | $6.00 | ₹43 |
| **Media Storage** | 500 GB S3 Intelligent-Tiering + Lifecycle | $12.50 | $150.00 | ₹1,075 |
| **CDN / CloudFront** | PriceClass_All, 1 TB Data Out + 5M requests | $12.00 | $144.00 | ₹1,032 |
| **Edge Security (AWS WAF)** | 1 WebACL + 3 Managed Rule Sets + Requests | $9.20 | $110.40 | ₹791 |
| **DNS & Routing** | Route 53 Hosted Zone + Health Check failover | $1.00 | $12.00 | ₹86 |
| **CloudWatch Observability** | 20 GB log ingestion + Insights + Metric Alarms | $12.00 | $144.00 | ₹1,032 |
| **Total** | | **$350.50 / mo** | **$4,205.89 / yr** | **₹30,143 / mo** |

---

## 4. Comprehensive Comparative Matrix

| Feature / Dimension | Tier 1: Basic (Dev / PoC) | Tier 2: Standard (Dept. Prod) | Tier 3: Production (Institutional) | Tier 4: High Availability (Enterprise) |
| :--- | :--- | :--- | :--- | :--- |
| **Target Audience** | Dev, Testing, Academic PoC | KFRI Internal & Field Teams | Statewide Public Portal | High-Volume State Mission-Critical |
| **Concurrent Users** | 1 – 20 | 20 – 150 | 150 – 1,000+ | 1,000 – 5,000+ (Auto-scaled) |
| **Backend Compute** | 1x `t3.micro` (2 vCPU, 1 GB) | 1x `t3.small` (2 vCPU, 2 GB) | 2x `t3.small` (4 vCPU, 4 GB total) | 2x–6x `t3.medium` (4–12 vCPU) |
| **Compute Architecture** | Single-Instance (No ALB) | Single-Instance (No ALB) | Load-Balanced (ALB + ASG) | Multi-AZ Load-Balanced (ALB + ASG) |
| **EBS Storage** | 20 GB `gp3` | 30 GB `gp3` | 60 GB `gp3` (2x 30 GB) | 100 GB `gp3` (2x 50 GB) |
| **Public IPv4 Fee** | Included ($3.65/mo) | Included ($3.65/mo) | $0.00 (Private Subnets) | $0.00 (Private Subnets) |
| **RDS Database** | `db.t3.micro` (1 GB RAM) | `db.t3.small` (2 GB RAM) | `db.t3.medium` (4 GB RAM) | `db.t3.medium` Multi-AZ (4 GB RAM) |
| **RDS Redundancy** | Single-AZ | Single-AZ | Single-AZ + Daily Snapshots | **Multi-AZ Synchronous Replica** |
| **RDS Storage** | 20 GB `gp3` | 50 GB `gp3` | 100 GB `gp3` | 250 GB `gp3` Multi-AZ |
| **Backup Retention** | 7 days | 7 days | 14 days | 30 days PITR |
| **Media S3 Storage** | 5 GB | 50 GB | 200 GB | 500 GB (Intelligent-Tiering) |
| **CloudFront CDN** | PriceClass_100 | PriceClass_200 (India/Asia) | PriceClass_200 + Custom SSL | PriceClass_All + AWS WAF |
| **Target Availability (SLA)**| ~99.0% | ~99.5% | ~99.9% | **>99.95% (Multi-AZ Failover)** |
| **Recovery Time (RTO)** | 1–2 hours (Manual restart) | 30–60 mins (Snapshot restore)| 10–15 mins (Auto-relaunch) | **<60 seconds (Auto-failover)** |
| **Monthly Cost (Free Tier)**| **$3.65 / mo** (₹314) | N/A | N/A | N/A |
| **Monthly Cost (On-Demand)**| **$33.87 / mo** (₹2,913) | **$67.47 / mo** (₹5,802) | **$155.90 / mo** (₹13,407) | **$350.50 / mo** (₹30,143) |
| **Annual Cost (On-Demand)** | **$406.40 / yr** (₹34,950) | **$809.58 / yr** (₹69,624) | **$1,870.74 / yr** (₹160,884) | **$4,205.89 / yr** (₹361,706) |
| **1-Yr Savings Plan / RI** | ~$28.00 / mo (-17%) | ~$53.00 / mo (-21%) | ~$118.00 / mo (-24%) | ~$248.00 / mo (-29%) |

---

## 5. Cost Optimization Strategies & Best Practices

1. **Adopt AWS Graviton Processors (`t4g` & `db.t4g`)**
   - The CloudFormation template includes `t4g.micro`, `t4g.small`, and `db.t4g.micro` in its allowed parameters.
   - Graviton2 ARM-based instances deliver up to **20% lower cost** and **up to 40% better performance** per dollar compared to x86 T3 instances.
2. **Purchase 1-Year Compute Savings Plans & RDS Reserved Instances**
   - If deploying Tier 2, 3, or 4 for long-term production, committing to a 1-year No-Upfront Compute Savings Plan reduces EC2 costs by **~25%–30%**.
   - Committing to a 1-year RDS Reserved Instance reduces database compute costs by **~30%–35%**.
3. **S3 Intelligent-Tiering & Lifecycle Expiration**
   - Observations, field audio, and specimen photos uploaded to `MediaBucket` can be automatically shifted to S3 Standard-IA or Glacier Flexible Retrieval after 90–180 days, reducing S3 storage unit costs by **50% to 80%**.
4. **CloudFront Caching Strategy**
   - The CloudFront distribution in `cloudformation.yaml` already sets `Managed-CachingOptimized` for static SPA assets and `Managed-CachingDisabled` for `/api/*`. Ensuring static image attachments in `MediaBucket` are also cached through CloudFront reduces direct S3 GET request costs and bandwidth fees to zero.
5. **Scheduled Non-Production Environments**
   - For Dev/Staging environments (e.g. `EnvironmentName: dev`), use AWS Instance Scheduler or Lambda to stop EC2 and RDS instances outside of working hours (e.g., 9:00 AM – 7:00 PM, Monday–Friday), yielding an instant **~65% cost reduction**.

---

## 6. Assumptions & Pricing Methodology

1. **Pricing Source & AWS Region:** All calculations reflect current AWS On-Demand rates for the **Asia Pacific (Mumbai) / `ap-south-1`** region as published in the official AWS Pricing Calculator and AWS API.
2. **Billing Hours:** Calculated based on a standard 730-hour operating month (365 days / 12 months × 24 hours).
3. **Currency Conversion:** Estimated at an indicative rate of **1 USD = 86.00 INR**. Real billing is converted at the exchange rate on the date of invoicing by AWS India (Amazon Internet Services Private Limited - AISPL).
4. **Taxes:** Estimates exclude applicable local taxes (e.g. 18% Indian GST).
5. **No Hidden Resources:** These estimates strictly correspond to the resources declared in `cloudformation.yaml` (Frontend S3, CloudFront CDN, Beanstalk Docker EC2/EBS, RDS PostgreSQL, Media S3, and IAM). No unneeded NAT Gateways, Transit Gateways, Bastion Hosts, or dedicated caching tiers have been added.
