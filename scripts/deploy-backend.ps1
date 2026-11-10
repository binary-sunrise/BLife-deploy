<#
.SYNOPSIS
    Packages and deploys the B-Life FastAPI backend to AWS Elastic Beanstalk.
#>
param(
    [string]$BackendDir = "..\BLife-Backend",
    [string]$Region = "ap-south-1",
    [string]$AppName = "blife-backend",
    [string]$EnvName = "blife-backend-prod"
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Packaging & Deploying Backend Application" -ForegroundColor Cyan
Write-Host " Backend Source: $BackendDir" -ForegroundColor Cyan
Write-Host " App Name: $AppName" -ForegroundColor Cyan
Write-Host " Env Name: $EnvName" -ForegroundColor Cyan
Write-Host " Region: $Region" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$ResolvedBackendDir = Resolve-Path $BackendDir
$TempZip = Join-Path (Get-Location) "deploy-backend.zip"

if (Test-Path $TempZip) {
    Remove-Item $TempZip -Force
}

Write-Host "1. Generating deployment package..." -ForegroundColor Yellow
$excludePatterns = @("*\.git*", "*\.venv*", "*\__pycache__*", "*\tests*", "*\.pytest_cache*", "*\.ruff_cache*", "*\.mypy_cache*", "*\deploy*")

$files = Get-ChildItem -Path $ResolvedBackendDir -Recurse -File | Where-Object {
    $relativePath = $_.FullName.Substring($ResolvedBackendDir.Path.Length + 1)
    $skip = $false
    foreach ($pat in $excludePatterns) {
        if ($relativePath -like $pat -or $_.FullName -like $pat) {
            $skip = $true
            break
        }
    }
    -not $skip
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::Open($TempZip, [System.IO.Compression.ZipArchiveMode]::Create)
foreach ($file in $files) {
    $entryName = $file.FullName.Substring($ResolvedBackendDir.Path.Length + 1).Replace("\", "/")
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file.FullName, $entryName) | Out-Null
}
$zip.Dispose()
Write-Host "[OK] Archive created ($([math]::Round((Get-Item $TempZip).Length / 1MB, 2)) MB)." -ForegroundColor Green

$versionLabel = "backend-" + (Get-Date -UFormat "%s")
Write-Host "2. Querying Elastic Beanstalk S3 storage location..." -ForegroundColor Yellow
$s3Bucket = (aws elasticbeanstalk create-storage-location --region $Region --output text --query "S3Bucket").Trim()
$s3Key = "$AppName/$versionLabel.zip"

Write-Host "3. Uploading $TempZip to s3://$s3Bucket/$s3Key..." -ForegroundColor Yellow
aws s3 cp $TempZip "s3://$s3Bucket/$s3Key" --region $Region
Remove-Item $TempZip -Force

Write-Host "4. Creating application version '$versionLabel'..." -ForegroundColor Yellow
aws elasticbeanstalk create-application-version `
    --application-name $AppName `
    --version-label $versionLabel `
    --source-bundle S3Bucket="$s3Bucket",S3Key="$s3Key" `
    --region $Region

Write-Host "5. Updating environment '$EnvName'..." -ForegroundColor Yellow
aws elasticbeanstalk update-environment `
    --environment-name $EnvName `
    --version-label $versionLabel `
    --region $Region

Write-Host "Waiting for environment update to finish..." -ForegroundColor Yellow
aws elasticbeanstalk wait environment-updated `
    --environment-name $EnvName `
    --region $Region

Write-Host "[OK] Backend deployment complete!" -ForegroundColor Green

