<#
.SYNOPSIS
    Deploys or updates the B-Life AWS CloudFormation infrastructure stack.
.PARAMETER StackName
    The name of the CloudFormation stack (default: 'blife-prod').
.PARAMETER Region
    The AWS region to deploy to (default: 'ap-south-1').
.PARAMETER ParamFile
    Path to the parameters JSON file (default: 'parameters/parameters.prod.json').
#>
param(
    [string]$StackName = "blife-stack",
    [string]$Region = "ap-south-1",
    [string]$ParamFile = "parameters/parameters.prod.json"
)

$ErrorActionPreference = "Stop"
$TemplateFile = "cloudformation.yaml"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " AWS CloudFormation Deployment: $StackName" -ForegroundColor Cyan
Write-Host " Region: $Region" -ForegroundColor Cyan
Write-Host " Template: $TemplateFile" -ForegroundColor Cyan
Write-Host " Parameters: $ParamFile" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

if (-not (Test-Path $ParamFile)) {
    Write-Error "Parameters file '$ParamFile' not found. Please copy parameters/parameters.prod.json.example to $ParamFile and update values."
    exit 1
}

Write-Host "1. Validating CloudFormation template..." -ForegroundColor Yellow
aws cloudformation validate-template `
    --template-body "file://$TemplateFile" `
    --region $Region | Out-Null
Write-Host "[OK] Template is valid." -ForegroundColor Green

# Check if stack already exists
$stackExists = $false
try {
    aws cloudformation describe-stacks --stack-name $StackName --region $Region 2>$null | Out-Null
    $stackExists = ($LASTEXITCODE -eq 0)
} catch {
    $stackExists = $false
}

if ($stackExists) {
    Write-Host "2. Stack '$StackName' exists. Creating change set..." -ForegroundColor Yellow
    $changeSetName = "update-" + (Get-Date -UFormat "%s")
    
    aws cloudformation create-change-set `
        --stack-name $StackName `
        --change-set-name $changeSetName `
        --template-body "file://$TemplateFile" `
        --parameters "file://$ParamFile" `
        --capabilities CAPABILITY_NAMED_IAM `
        --region $Region

    Write-Host "Waiting for change set to be created..." -ForegroundColor Yellow
    aws cloudformation wait change-set-create-complete `
        --stack-name $StackName `
        --change-set-name $changeSetName `
        --region $Region

    Write-Host "Executing change set..." -ForegroundColor Yellow
    aws cloudformation execute-change-set `
        --stack-name $StackName `
        --change-set-name $changeSetName `
        --region $Region

    Write-Host "Waiting for stack update to complete..." -ForegroundColor Yellow
    aws cloudformation wait stack-update-complete `
        --stack-name $StackName `
        --region $Region
    Write-Host "[OK] Stack updated successfully." -ForegroundColor Green
} else {
    Write-Host "2. Creating stack '$StackName'..." -ForegroundColor Yellow
    aws cloudformation create-stack `
        --stack-name $StackName `
        --template-body "file://$TemplateFile" `
        --parameters "file://$ParamFile" `
        --capabilities CAPABILITY_NAMED_IAM `
        --region $Region

    Write-Host "Waiting for stack creation to complete (this may take 10-15 minutes for RDS & CloudFront)..." -ForegroundColor Yellow
    aws cloudformation wait stack-create-complete `
        --stack-name $StackName `
        --region $Region
    Write-Host "[OK] Stack created successfully." -ForegroundColor Green
}

Write-Host "`n==================== Stack Outputs ====================" -ForegroundColor Cyan
aws cloudformation describe-stacks `
    --stack-name $StackName `
    --region $Region `
    --query "Stacks[0].Outputs[*].[OutputKey, OutputValue]" `
    --output table
Write-Host "==========================================================" -ForegroundColor Cyan

