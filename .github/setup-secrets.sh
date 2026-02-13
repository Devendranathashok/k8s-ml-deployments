#!/bin/bash
# Script to help set up GitHub Actions secrets using GitHub CLI
# Prerequisites: Install GitHub CLI (gh) and authenticate: gh auth login

set -e

echo "=================================="
echo "GitHub Actions Secrets Setup"
echo "=================================="
echo ""

# Check if gh is installed
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) is not installed."
    echo "Install from: https://cli.github.com/"
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    echo "❌ Not authenticated with GitHub CLI"
    echo "Run: gh auth login"
    exit 1
fi

echo "✅ GitHub CLI is installed and authenticated"
echo ""

# Function to add secret
add_secret() {
    local secret_name=$1
    local secret_prompt=$2
    local secret_value

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Setting up: $secret_name"
    echo "$secret_prompt"
    echo ""
    read -rsp "Enter value (input hidden): " secret_value
    echo ""

    if [ -z "$secret_value" ]; then
        echo "⚠️  Skipped (empty value)"
        echo ""
        return
    fi

    if gh secret set "$secret_name" --body "$secret_value"; then
        echo "✅ $secret_name added successfully"
    else
        echo "❌ Failed to add $secret_name"
    fi
    echo ""
}

# Function to add secret from file
add_secret_from_file() {
    local secret_name=$1
    local secret_prompt=$2
    local file_path

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Setting up: $secret_name"
    echo "$secret_prompt"
    echo ""
    read -rp "Enter file path: " file_path

    if [ -z "$file_path" ]; then
        echo "⚠️  Skipped (empty path)"
        echo ""
        return
    fi

    if [ ! -f "$file_path" ]; then
        echo "❌ File not found: $file_path"
        echo ""
        return
    fi

    local encoded_content
    encoded_content=$(cat "$file_path" | base64 -w 0 2>/dev/null || cat "$file_path" | base64)

    if gh secret set "$secret_name" --body "$encoded_content"; then
        echo "✅ $secret_name added successfully"
    else
        echo "❌ Failed to add $secret_name"
    fi
    echo ""
}

# Main menu
echo "Select your Docker registry:"
echo "1) Docker Hub"
echo "2) GitHub Container Registry (GHCR)"
echo "3) Google Container Registry (GCR)"
echo "4) Amazon ECR"
echo "5) Skip Docker registry setup"
echo ""
read -rp "Enter choice (1-5): " registry_choice
echo ""

case $registry_choice in
    1)
        add_secret "DOCKER_USERNAME" "Your Docker Hub username"
        add_secret "DOCKER_PASSWORD" "Your Docker Hub access token (from https://hub.docker.com/settings/security)"
        ;;
    2)
        echo "ℹ️  For GHCR, GITHUB_TOKEN is automatically provided by GitHub Actions"
        echo "No additional secrets needed for authentication"
        echo ""
        ;;
    3)
        add_secret_from_file "GCR_SERVICE_ACCOUNT_KEY" "Path to your GCP service account JSON file (will be base64 encoded)"
        ;;
    4)
        add_secret "AWS_ACCESS_KEY_ID" "Your AWS Access Key ID"
        add_secret "AWS_SECRET_ACCESS_KEY" "Your AWS Secret Access Key"
        add_secret "AWS_REGION" "Your AWS region (e.g., us-east-1)"
        ;;
    5)
        echo "⚠️  Skipping Docker registry setup"
        echo ""
        ;;
    *)
        echo "❌ Invalid choice"
        exit 1
        ;;
esac

# Kubernetes configuration
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Setting up Kubernetes configuration"
echo ""
read -rp "Do you want to add KUBE_CONFIG? (y/n): " add_kube
if [[ $add_kube =~ ^[Yy]$ ]]; then
    add_secret_from_file "KUBE_CONFIG" "Path to your kubeconfig file (usually ~/.kube/config)"
fi

# Optional notifications
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Optional: Notification Services"
echo ""
read -rp "Do you want to set up Slack notifications? (y/n): " add_slack
if [[ $add_slack =~ ^[Yy]$ ]]; then
    add_secret "SLACK_WEBHOOK" "Your Slack webhook URL (from https://api.slack.com/messaging/webhooks)"
fi

read -rp "Do you want to set up Discord notifications? (y/n): " add_discord
if [[ $add_discord =~ ^[Yy]$ ]]; then
    add_secret "DISCORD_WEBHOOK" "Your Discord webhook URL"
fi

read -rp "Do you want to set up email notifications? (y/n): " add_email
if [[ $add_email =~ ^[Yy]$ ]]; then
    add_secret "EMAIL_USERNAME" "Your email address"
    add_secret "EMAIL_PASSWORD" "Your email app password"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Secret setup complete!"
echo ""
echo "To view configured secrets:"
echo "  gh secret list"
echo ""
echo "To test your workflows:"
echo "  1. Push to your repository"
echo "  2. Go to Actions tab on GitHub"
echo "  3. View workflow runs"
echo ""
echo "For more information, see: .github/WORKFLOWS.md"
echo "=================================="
