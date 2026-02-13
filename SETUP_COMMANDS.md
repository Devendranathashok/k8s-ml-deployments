# Quick Setup Commands

Copy-paste these commands to set up your Docker Hub + GKE pipeline.

## 🔑 Prerequisites

1. Docker Hub account
2. GCP project with GKE cluster
3. GitHub CLI installed (`gh`)

---

## Step 1: Docker Hub Access Token

1. Go to: https://hub.docker.com/settings/security
2. Click **New Access Token**
3. Copy the token

---

## Step 2: Add All Secrets

```bash
# Navigate to your repository
cd c:/Users/ashok/ml-k8s-deployment

# Authenticate with GitHub (if needed)
gh auth login

# === Docker Hub Secrets ===
gh secret set DOCKER_USERNAME --body "your-dockerhub-username"
gh secret set DOCKER_PASSWORD --body "your-docker-hub-access-token"

# === GCP Project ===
gh secret set GCP_PROJECT_ID --body "celestial-ridge-481607-g"

# === GKE Cluster Info ===
# Get your cluster name and zone first:
gcloud container clusters list

# Then set them:
gh secret set GKE_CLUSTER_NAME --body "your-cluster-name"
gh secret set GKE_ZONE --body "us-central1-a"

# === GCP Service Account ===
# Run the automated setup:
cd .github
chmod +x setup-gke.sh
./setup-gke.sh
```

---

## Step 3: Verify Secrets

```bash
gh secret list
```

**Expected output:**
```
DOCKER_PASSWORD     Updated 2024-XX-XX
DOCKER_USERNAME     Updated 2024-XX-XX
GCP_PROJECT_ID      Updated 2024-XX-XX
GCP_SA_KEY          Updated 2024-XX-XX
GKE_CLUSTER_NAME    Updated 2024-XX-XX
GKE_ZONE            Updated 2024-XX-XX
```

---

## Step 4: Deploy!

```bash
# Commit and push
git add .
git commit -m "Configure Docker Hub + GKE pipeline"
git push origin main

# Watch it deploy
gh run watch
```

---

## 🔍 Quick Reference

### View workflow status
```bash
gh run list
gh run view --log
```

### Check Docker Hub images
```bash
# Browser
https://hub.docker.com/r/YOUR-USERNAME/ml-model/tags

# CLI
docker pull YOUR-USERNAME/ml-model:latest
```

### Check GKE deployment
```bash
# Get credentials
gcloud container clusters get-credentials YOUR-CLUSTER --zone=YOUR-ZONE

# Check status
kubectl get all -n ml-models

# Get external IP
kubectl get service ml-model-service -n ml-models
```

### Test your model
```bash
# Get IP
export EXTERNAL_IP=$(kubectl get service ml-model-service -n ml-models -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Test
curl http://$EXTERNAL_IP/health
curl -X POST http://$EXTERNAL_IP/predict \
  -H "Content-Type: application/json" \
  -d '{"features": [5.1, 3.5, 1.4, 0.2]}'
```

---

## 🐛 Troubleshooting

### Forgot to get cluster info?
```bash
gcloud container clusters list --format="table(name,location)"
```

### Need to recreate service account?
```bash
cd .github
./setup-gke.sh
```

### Docker Hub image pull error?
Make your repository public or add image pull secret:
```bash
kubectl create secret docker-registry dockerhub-secret \
  --docker-server=docker.io \
  --docker-username=YOUR-USERNAME \
  --docker-password=YOUR-TOKEN \
  --docker-email=YOUR-EMAIL \
  -n ml-models
```

---

**Done! See [DOCKER_HUB_GKE_SETUP.md](DOCKER_HUB_GKE_SETUP.md) for full documentation.**
