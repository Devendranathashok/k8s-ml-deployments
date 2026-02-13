# PowerShell script for GKE setup with GitHub Actions
# This script creates a service account and configures GitHub secrets

$ErrorActionPreference = "Stop"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "GKE Setup for GitHub Actions" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Check prerequisites
Write-Host "Checking prerequisites..." -ForegroundColor Yellow

try {
    $null = gcloud --version
    Write-Host "✅ gcloud CLI is installed" -ForegroundColor Green
} catch {
    Write-Host "❌ gcloud CLI is not installed" -ForegroundColor Red
    Write-Host "Install from: https://cloud.google.com/sdk/docs/install" -ForegroundColor Yellow
    exit 1
}

$UseGhCli = $false
try {
    $null = gh --version
    Write-Host "✅ GitHub CLI is installed" -ForegroundColor Green

    $null = gh auth status 2>&1
    Write-Host "✅ GitHub CLI is authenticated" -ForegroundColor Green
    $UseGhCli = $true
} catch {
    Write-Host "⚠️  GitHub CLI is not installed or not authenticated (optional)" -ForegroundColor Yellow
    Write-Host "Install from: https://cli.github.com/" -ForegroundColor Yellow
    $UseGhCli = $false
}

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "GCP Configuration" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host ""

# Get current project
$CurrentProject = (gcloud config get-value project 2>$null)
if ($CurrentProject) {
    Write-Host "Current GCP project: $CurrentProject" -ForegroundColor Cyan
    $UseCurrent = Read-Host "Use this project? (y/n)"
    if ($UseCurrent -match "^[Yy]$") {
        $ProjectId = $CurrentProject
    } else {
        $ProjectId = Read-Host "Enter your GCP project ID"
    }
} else {
    $ProjectId = Read-Host "Enter your GCP project ID"
}

# Set project
gcloud config set project $ProjectId
Write-Host "✅ Project set to: $ProjectId" -ForegroundColor Green
Write-Host ""

# Get cluster information
$ClusterName = Read-Host "Enter your GKE cluster name"
$Zone = Read-Host "Enter your GKE cluster zone (e.g., us-central1-a)"

Write-Host ""
Write-Host "Verifying cluster exists..." -ForegroundColor Yellow
try {
    $null = gcloud container clusters describe $ClusterName --zone=$Zone 2>&1
    Write-Host "✅ Cluster found: $ClusterName" -ForegroundColor Green
} catch {
    Write-Host "❌ Cluster not found: $ClusterName in zone $Zone" -ForegroundColor Red
    Write-Host "Please check your cluster name and zone" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "Service Account Setup" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host ""

$SaName = "github-actions-sa"
$InputSaName = Read-Host "Service account name [github-actions-sa]"
if ($InputSaName) {
    $SaName = $InputSaName
}

$SaEmail = "$SaName@$ProjectId.iam.gserviceaccount.com"
$KeyFile = "github-actions-key.json"

Write-Host ""
Write-Host "Creating service account: $SaName..." -ForegroundColor Yellow

# Check if service account exists
try {
    $null = gcloud iam service-accounts describe $SaEmail 2>&1
    Write-Host "⚠️  Service account already exists" -ForegroundColor Yellow
    $UseExisting = Read-Host "Use existing service account? (y/n)"
    if ($UseExisting -notmatch "^[Yy]$") {
        Write-Host "Exiting..." -ForegroundColor Yellow
        exit 1
    }
} catch {
    gcloud iam service-accounts create $SaName `
      --display-name="GitHub Actions Service Account" `
      --description="Service account for GitHub Actions CI/CD"
    Write-Host "✅ Service account created" -ForegroundColor Green
}

Write-Host ""
Write-Host "Granting IAM permissions..." -ForegroundColor Yellow

# Storage admin for GCR
Write-Host "  - Granting storage.admin (for GCR)..." -ForegroundColor White
gcloud projects add-iam-policy-binding $ProjectId `
  --member="serviceAccount:$SaEmail" `
  --role="roles/storage.admin" `
  --condition=None `
  | Out-Null

# GKE developer
Write-Host "  - Granting container.developer (for GKE)..." -ForegroundColor White
gcloud projects add-iam-policy-binding $ProjectId `
  --member="serviceAccount:$SaEmail" `
  --role="roles/container.developer" `
  --condition=None `
  | Out-Null

# Optional: Artifact Registry
$GrantAr = Read-Host "Grant Artifact Registry permissions? (y/n)"
if ($GrantAr -match "^[Yy]$") {
    Write-Host "  - Granting artifactregistry.writer..." -ForegroundColor White
    gcloud projects add-iam-policy-binding $ProjectId `
      --member="serviceAccount:$SaEmail" `
      --role="roles/artifactregistry.writer" `
      --condition=None `
      | Out-Null
}

Write-Host "✅ IAM permissions granted" -ForegroundColor Green

Write-Host ""
Write-Host "Creating service account key..." -ForegroundColor Yellow

# Delete old key file if exists
if (Test-Path $KeyFile) {
    Remove-Item $KeyFile
    Write-Host "  - Removed old key file" -ForegroundColor White
}

gcloud iam service-accounts keys create $KeyFile `
  --iam-account=$SaEmail

Write-Host "✅ Service account key created: $KeyFile" -ForegroundColor Green

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "GitHub Secrets Setup" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host ""

# Base64 encode the key
$KeyContent = Get-Content -Path $KeyFile -Raw -Encoding UTF8
$SaKeyBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($KeyContent))

if ($UseGhCli) {
    Write-Host "Adding secrets using GitHub CLI..." -ForegroundColor Yellow

    $SaKeyBase64 | gh secret set GCP_SA_KEY
    Write-Host "✅ GCP_SA_KEY added" -ForegroundColor Green

    $ProjectId | gh secret set GCP_PROJECT_ID
    Write-Host "✅ GCP_PROJECT_ID added" -ForegroundColor Green

    $ClusterName | gh secret set GKE_CLUSTER_NAME
    Write-Host "✅ GKE_CLUSTER_NAME added" -ForegroundColor Green

    $Zone | gh secret set GKE_ZONE
    Write-Host "✅ GKE_ZONE added" -ForegroundColor Green

    Write-Host ""
    Write-Host "✅ All secrets added to GitHub!" -ForegroundColor Green
} else {
    Write-Host "Add these secrets manually to GitHub:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Secret Name: GCP_SA_KEY" -ForegroundColor Cyan
    Write-Host "Value (base64 encoded):"
    Write-Host $SaKeyBase64 -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Secret Name: GCP_PROJECT_ID" -ForegroundColor Cyan
    Write-Host "Value: $ProjectId"
    Write-Host ""
    Write-Host "Secret Name: GKE_CLUSTER_NAME" -ForegroundColor Cyan
    Write-Host "Value: $ClusterName"
    Write-Host ""
    Write-Host "Secret Name: GKE_ZONE" -ForegroundColor Cyan
    Write-Host "Value: $Zone"
    Write-Host ""
    Write-Host "Go to: https://github.com/<your-repo>/settings/secrets/actions" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "Security Cleanup" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host ""

$DeleteKey = Read-Host "Delete local service account key file? (RECOMMENDED) (y/n)"
if ($DeleteKey -match "^[Yy]$") {
    Remove-Item $KeyFile
    Write-Host "✅ Local key file deleted" -ForegroundColor Green
} else {
    Write-Host "⚠️  WARNING: Keep this file secure! Do not commit to git!" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host ""
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  - Project: $ProjectId"
Write-Host "  - Cluster: $ClusterName"
Write-Host "  - Zone: $Zone"
Write-Host "  - Service Account: $SaEmail"
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Verify secrets in GitHub: gh secret list"
Write-Host "  2. Update workflow file with your project ID"
Write-Host "  3. Push to main branch to trigger deployment"
Write-Host ""
Write-Host "For more information, see: .github/GKE_SETUP.md" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
