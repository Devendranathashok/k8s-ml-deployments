#!/bin/bash
# Automated GKE setup script for GitHub Actions
# This script creates a service account and configures GitHub secrets

set -e

echo "============================================"
echo "GKE Setup for GitHub Actions"
echo "============================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Check prerequisites
echo "Checking prerequisites..."

if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}❌ gcloud CLI is not installed${NC}"
    echo "Install from: https://cloud.google.com/sdk/docs/install"
    exit 1
fi
echo -e "${GREEN}✅ gcloud CLI is installed${NC}"

if ! command -v gh &> /dev/null; then
    echo -e "${YELLOW}⚠️  GitHub CLI is not installed (optional but recommended)${NC}"
    echo "Install from: https://cli.github.com/"
    USE_GH_CLI=false
else
    echo -e "${GREEN}✅ GitHub CLI is installed${NC}"
    USE_GH_CLI=true

    # Check if authenticated
    if ! gh auth status &> /dev/null; then
        echo -e "${YELLOW}⚠️  Not authenticated with GitHub CLI${NC}"
        echo "Run: gh auth login"
        USE_GH_CLI=false
    fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "GCP Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Get current project
CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null || echo "")
if [ -n "$CURRENT_PROJECT" ]; then
    echo -e "Current GCP project: ${CYAN}$CURRENT_PROJECT${NC}"
    read -p "Use this project? (y/n): " USE_CURRENT
    if [[ $USE_CURRENT =~ ^[Yy]$ ]]; then
        PROJECT_ID=$CURRENT_PROJECT
    else
        read -p "Enter your GCP project ID: " PROJECT_ID
    fi
else
    read -p "Enter your GCP project ID: " PROJECT_ID
fi

# Set project
gcloud config set project $PROJECT_ID
echo -e "${GREEN}✅ Project set to: $PROJECT_ID${NC}"
echo ""

# Get cluster information
read -p "Enter your GKE cluster name: " CLUSTER_NAME
read -p "Enter your GKE cluster zone (e.g., us-central1-a): " ZONE

echo ""
echo "Verifying cluster exists..."
if gcloud container clusters describe $CLUSTER_NAME --zone=$ZONE &>/dev/null; then
    echo -e "${GREEN}✅ Cluster found: $CLUSTER_NAME${NC}"
else
    echo -e "${RED}❌ Cluster not found: $CLUSTER_NAME in zone $ZONE${NC}"
    echo "Please check your cluster name and zone"
    exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Service Account Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

SA_NAME="github-actions-sa"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
KEY_FILE="github-actions-key.json"

read -p "Service account name [github-actions-sa]: " INPUT_SA_NAME
if [ -n "$INPUT_SA_NAME" ]; then
    SA_NAME=$INPUT_SA_NAME
    SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
fi

echo ""
echo "Creating service account: $SA_NAME..."

# Check if service account exists
if gcloud iam service-accounts describe $SA_EMAIL &>/dev/null; then
    echo -e "${YELLOW}⚠️  Service account already exists${NC}"
    read -p "Use existing service account? (y/n): " USE_EXISTING
    if [[ ! $USE_EXISTING =~ ^[Yy]$ ]]; then
        echo "Exiting..."
        exit 1
    fi
else
    gcloud iam service-accounts create $SA_NAME \
      --display-name="GitHub Actions Service Account" \
      --description="Service account for GitHub Actions CI/CD"
    echo -e "${GREEN}✅ Service account created${NC}"
fi

echo ""
echo "Granting IAM permissions..."

# Storage admin for GCR
echo "  - Granting storage.admin (for GCR)..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/storage.admin" \
  --condition=None \
  > /dev/null

# GKE developer
echo "  - Granting container.developer (for GKE)..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/container.developer" \
  --condition=None \
  > /dev/null

# Optional: Artifact Registry
read -p "Grant Artifact Registry permissions? (y/n): " GRANT_AR
if [[ $GRANT_AR =~ ^[Yy]$ ]]; then
    echo "  - Granting artifactregistry.writer..."
    gcloud projects add-iam-policy-binding $PROJECT_ID \
      --member="serviceAccount:${SA_EMAIL}" \
      --role="roles/artifactregistry.writer" \
      --condition=None \
      > /dev/null
fi

echo -e "${GREEN}✅ IAM permissions granted${NC}"

echo ""
echo "Creating service account key..."

# Delete old key file if exists
if [ -f "$KEY_FILE" ]; then
    rm $KEY_FILE
    echo "  - Removed old key file"
fi

gcloud iam service-accounts keys create $KEY_FILE \
  --iam-account=$SA_EMAIL

echo -e "${GREEN}✅ Service account key created: $KEY_FILE${NC}"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "GitHub Secrets Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Base64 encode the key
SA_KEY_BASE64=$(cat $KEY_FILE | base64 -w 0)

if [ "$USE_GH_CLI" = true ]; then
    echo "Adding secrets using GitHub CLI..."

    gh secret set GCP_SA_KEY --body "$SA_KEY_BASE64"
    echo -e "${GREEN}✅ GCP_SA_KEY added${NC}"

    gh secret set GCP_PROJECT_ID --body "$PROJECT_ID"
    echo -e "${GREEN}✅ GCP_PROJECT_ID added${NC}"

    gh secret set GKE_CLUSTER_NAME --body "$CLUSTER_NAME"
    echo -e "${GREEN}✅ GKE_CLUSTER_NAME added${NC}"

    gh secret set GKE_ZONE --body "$ZONE"
    echo -e "${GREEN}✅ GKE_ZONE added${NC}"

    echo ""
    echo -e "${GREEN}✅ All secrets added to GitHub!${NC}"
else
    echo "Add these secrets manually to GitHub:"
    echo ""
    echo -e "${CYAN}Secret Name: GCP_SA_KEY${NC}"
    echo "Value (base64 encoded):"
    echo "$SA_KEY_BASE64"
    echo ""
    echo -e "${CYAN}Secret Name: GCP_PROJECT_ID${NC}"
    echo "Value: $PROJECT_ID"
    echo ""
    echo -e "${CYAN}Secret Name: GKE_CLUSTER_NAME${NC}"
    echo "Value: $CLUSTER_NAME"
    echo ""
    echo -e "${CYAN}Secret Name: GKE_ZONE${NC}"
    echo "Value: $ZONE"
    echo ""
    echo "Go to: https://github.com/<your-repo>/settings/secrets/actions"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Security Cleanup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

read -p "Delete local service account key file? (RECOMMENDED) (y/n): " DELETE_KEY
if [[ $DELETE_KEY =~ ^[Yy]$ ]]; then
    rm $KEY_FILE
    echo -e "${GREEN}✅ Local key file deleted${NC}"
else
    echo -e "${YELLOW}⚠️  WARNING: Keep this file secure! Do not commit to git!${NC}"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Setup Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Summary:"
echo "  - Project: $PROJECT_ID"
echo "  - Cluster: $CLUSTER_NAME"
echo "  - Zone: $ZONE"
echo "  - Service Account: $SA_EMAIL"
echo ""
echo "Next steps:"
echo "  1. Verify secrets in GitHub: gh secret list"
echo "  2. Update workflow file with your project ID"
echo "  3. Push to main branch to trigger deployment"
echo ""
echo "For more information, see: .github/GKE_SETUP.md"
echo "============================================"
