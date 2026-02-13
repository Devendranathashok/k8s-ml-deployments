# PowerShell script to help set up GitHub Actions secrets using GitHub CLI
# Prerequisites: Install GitHub CLI (gh) and authenticate: gh auth login

$ErrorActionPreference = "Stop"

Write-Host "==================================" -ForegroundColor Cyan
Write-Host "GitHub Actions Secrets Setup" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""

# Check if gh is installed
try {
    $null = gh --version
    Write-Host "✅ GitHub CLI is installed" -ForegroundColor Green
} catch {
    Write-Host "❌ GitHub CLI (gh) is not installed." -ForegroundColor Red
    Write-Host "Install from: https://cli.github.com/" -ForegroundColor Yellow
    exit 1
}

# Check if authenticated
try {
    $null = gh auth status 2>&1
    Write-Host "✅ GitHub CLI is authenticated" -ForegroundColor Green
} catch {
    Write-Host "❌ Not authenticated with GitHub CLI" -ForegroundColor Red
    Write-Host "Run: gh auth login" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# Function to add secret
function Add-GitHubSecret {
    param(
        [string]$SecretName,
        [string]$Prompt
    )

    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    Write-Host "Setting up: $SecretName" -ForegroundColor Yellow
    Write-Host $Prompt -ForegroundColor White
    Write-Host ""

    $SecretValue = Read-Host "Enter value (input hidden)" -AsSecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecretValue)
    $PlainValue = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

    if ([string]::IsNullOrWhiteSpace($PlainValue)) {
        Write-Host "⚠️  Skipped (empty value)" -ForegroundColor Yellow
        Write-Host ""
        return
    }

    try {
        $PlainValue | gh secret set $SecretName
        Write-Host "✅ $SecretName added successfully" -ForegroundColor Green
    } catch {
        Write-Host "❌ Failed to add $SecretName" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
    Write-Host ""
}

# Function to add secret from file
function Add-GitHubSecretFromFile {
    param(
        [string]$SecretName,
        [string]$Prompt
    )

    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    Write-Host "Setting up: $SecretName" -ForegroundColor Yellow
    Write-Host $Prompt -ForegroundColor White
    Write-Host ""

    $FilePath = Read-Host "Enter file path"

    if ([string]::IsNullOrWhiteSpace($FilePath)) {
        Write-Host "⚠️  Skipped (empty path)" -ForegroundColor Yellow
        Write-Host ""
        return
    }

    # Expand path (handle ~ and environment variables)
    $FilePath = [System.IO.Path]::GetFullPath($FilePath.Replace("~", $env:USERPROFILE))

    if (-not (Test-Path $FilePath)) {
        Write-Host "❌ File not found: $FilePath" -ForegroundColor Red
        Write-Host ""
        return
    }

    try {
        $FileContent = Get-Content -Path $FilePath -Raw -Encoding UTF8
        $EncodedContent = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($FileContent))
        $EncodedContent | gh secret set $SecretName
        Write-Host "✅ $SecretName added successfully" -ForegroundColor Green
    } catch {
        Write-Host "❌ Failed to add $SecretName" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
    Write-Host ""
}

# Main menu
Write-Host "Select your Docker registry:" -ForegroundColor Cyan
Write-Host "1) Docker Hub"
Write-Host "2) GitHub Container Registry (GHCR)"
Write-Host "3) Google Container Registry (GCR)"
Write-Host "4) Amazon ECR"
Write-Host "5) Skip Docker registry setup"
Write-Host ""

$RegistryChoice = Read-Host "Enter choice (1-5)"
Write-Host ""

switch ($RegistryChoice) {
    "1" {
        Add-GitHubSecret -SecretName "DOCKER_USERNAME" -Prompt "Your Docker Hub username"
        Add-GitHubSecret -SecretName "DOCKER_PASSWORD" -Prompt "Your Docker Hub access token (from https://hub.docker.com/settings/security)"
    }
    "2" {
        Write-Host "ℹ️  For GHCR, GITHUB_TOKEN is automatically provided by GitHub Actions" -ForegroundColor Cyan
        Write-Host "No additional secrets needed for authentication" -ForegroundColor Cyan
        Write-Host ""
    }
    "3" {
        Add-GitHubSecretFromFile -SecretName "GCR_SERVICE_ACCOUNT_KEY" -Prompt "Path to your GCP service account JSON file (will be base64 encoded)"
    }
    "4" {
        Add-GitHubSecret -SecretName "AWS_ACCESS_KEY_ID" -Prompt "Your AWS Access Key ID"
        Add-GitHubSecret -SecretName "AWS_SECRET_ACCESS_KEY" -Prompt "Your AWS Secret Access Key"
        Add-GitHubSecret -SecretName "AWS_REGION" -Prompt "Your AWS region (e.g., us-east-1)"
    }
    "5" {
        Write-Host "⚠️  Skipping Docker registry setup" -ForegroundColor Yellow
        Write-Host ""
    }
    default {
        Write-Host "❌ Invalid choice" -ForegroundColor Red
        exit 1
    }
}

# Kubernetes configuration
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "Setting up Kubernetes configuration" -ForegroundColor Cyan
Write-Host ""

$AddKube = Read-Host "Do you want to add KUBE_CONFIG? (y/n)"
if ($AddKube -match "^[Yy]$") {
    Add-GitHubSecretFromFile -SecretName "KUBE_CONFIG" -Prompt "Path to your kubeconfig file (usually $env:USERPROFILE\.kube\config)"
}

# Optional notifications
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "Optional: Notification Services" -ForegroundColor Cyan
Write-Host ""

$AddSlack = Read-Host "Do you want to set up Slack notifications? (y/n)"
if ($AddSlack -match "^[Yy]$") {
    Add-GitHubSecret -SecretName "SLACK_WEBHOOK" -Prompt "Your Slack webhook URL (from https://api.slack.com/messaging/webhooks)"
}

$AddDiscord = Read-Host "Do you want to set up Discord notifications? (y/n)"
if ($AddDiscord -match "^[Yy]$") {
    Add-GitHubSecret -SecretName "DISCORD_WEBHOOK" -Prompt "Your Discord webhook URL"
}

$AddEmail = Read-Host "Do you want to set up email notifications? (y/n)"
if ($AddEmail -match "^[Yy]$") {
    Add-GitHubSecret -SecretName "EMAIL_USERNAME" -Prompt "Your email address"
    Add-GitHubSecret -SecretName "EMAIL_PASSWORD" -Prompt "Your email app password"
}

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "✅ Secret setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "To view configured secrets:" -ForegroundColor Cyan
Write-Host "  gh secret list" -ForegroundColor White
Write-Host ""
Write-Host "To test your workflows:" -ForegroundColor Cyan
Write-Host "  1. Push to your repository" -ForegroundColor White
Write-Host "  2. Go to Actions tab on GitHub" -ForegroundColor White
Write-Host "  3. View workflow runs" -ForegroundColor White
Write-Host ""
Write-Host "For more information, see: .github/WORKFLOWS.md" -ForegroundColor Yellow
Write-Host "==================================" -ForegroundColor Cyan
