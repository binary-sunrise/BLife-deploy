<#
.SYNOPSIS
    Builds and deploys the B-Life frontend application to AWS S3 & invalidates CloudFront.
#>
param(
    [string]$FrontendDir = "..\BLife-frontend",
    [string]$StackName = "blife-stack",
    [string]$Region = "ap-southeast-2"
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Building & Deploying Frontend Application" -ForegroundColor Cyan
Write-Host " Frontend Source: $FrontendDir" -ForegroundColor Cyan
Write-Host " Stack: $StackName" -ForegroundColor Cyan
Write-Host " Region: $Region" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$ResolvedFrontendDir = (Resolve-Path $FrontendDir).Path

Write-Host "1. Fetching stack outputs (Bucket & CloudFront ID)..." -ForegroundColor Yellow
$bucketName = (aws cloudformation describe-stacks `
    --stack-name $StackName `
    --region $Region `
    --query "Stacks[0].Outputs[?OutputKey=='FrontendBucketName'].OutputValue" `
    --output text).Trim()

$cfId = (aws cloudformation describe-stacks `
    --stack-name $StackName `
    --region $Region `
    --query "Stacks[0].Outputs[?OutputKey=='CloudFrontDistributionId'].OutputValue" `
    --output text).Trim()

Write-Host "Frontend Bucket: $bucketName" -ForegroundColor Green
Write-Host "CloudFront ID: $cfId" -ForegroundColor Green

Write-Host "2. Building frontend application..." -ForegroundColor Yellow
Push-Location $ResolvedFrontendDir
try {
    npm ci
    npm run build
} finally {
    Pop-Location
}

$distDir = Join-Path $ResolvedFrontendDir "dist"
if (-not (Test-Path $distDir)) {
    Write-Error "Build output dist directory was not created!"
    exit 1
}

Write-Host "3. Syncing build artifacts to s3://$bucketName..." -ForegroundColor Yellow
aws s3 sync $distDir "s3://$bucketName" --delete --region $Region

Write-Host "4. Invalidating CloudFront cache..." -ForegroundColor Yellow
aws cloudfront create-invalidation `
    --distribution-id $cfId `
    --paths "/*" | Out-Null

Write-Host "[OK] Frontend deployment complete!" -ForegroundColor Green

