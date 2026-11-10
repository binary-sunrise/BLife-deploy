<#
.SYNOPSIS
    Tears down the B-Life AWS CloudFormation infrastructure stack.
#>
param(
    [string]$StackName = "blife-stack",
    [string]$Region = "ap-south-1"
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Red
Write-Host " CAUTION: TEARDOWN INFRASTRUCTURE" -ForegroundColor Red
Write-Host " Stack: $StackName" -ForegroundColor Red
Write-Host " Region: $Region" -ForegroundColor Red
Write-Host "==========================================================" -ForegroundColor Red

$confirm = Read-Host "Are you sure you want to permanently delete stack '$StackName'? (type 'yes' to proceed)"
if ($confirm -ne "yes") {
    Write-Host "Aborted."
    exit 0
}

Write-Host "Deleting CloudFormation stack '$StackName'..." -ForegroundColor Yellow
aws cloudformation delete-stack --stack-name $StackName --region $Region

Write-Host "Waiting for stack deletion to complete..." -ForegroundColor Yellow
aws cloudformation wait stack-delete-complete --stack-name $StackName --region $Region

Write-Host "[OK] Stack '$StackName' deleted successfully." -ForegroundColor Green

