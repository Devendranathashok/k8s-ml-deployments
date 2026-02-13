# GKE Integration - Quick Start ⚡

Get your ML model deployed to GKE in 5 minutes!

## 🚀 One-Command Setup

**Windows (PowerShell):**
```powershell
cd .github
.\setup-gke.ps1
```

**Linux/macOS:**
```bash
cd .github
chmod +x setup-gke.sh
./setup-gke.sh
```

The script will:
- ✅ Create a GCP service account
- ✅ Grant required IAM permissions
- ✅ Generate service account key
- ✅ Add secrets to GitHub automatically
- ✅ Clean up sensitive files

## 📋 What You Need

Before running the script, have these ready:

1. **GCP Project ID** - Your Google Cloud project
2. **GKE Cluster Name** - Your existing cluster name
3. **GKE Zone** - e.g., `us-central1-a`

## 🎯 What Gets Created

### 1. **New GitHub Workflow**
[.github/workflows/ci-cd-gke.yml](.github/workflows/ci-cd-gke.yml)
- Builds and pushes to Google Container Registry (GCR)
- Deploys to your GKE cluster
- Supports both Standard K8s and KServe

### 2. **GCP Service Account**
```
Name: github-actions-sa
Roles:
  - storage.admin (for GCR)
  - container.developer (for GKE)
  - artifactregistry.writer (optional)
```

### 3. **GitHub Secrets**
```
GCP_SA_KEY          - Service account credentials
GCP_PROJECT_ID      - Your GCP project ID
GKE_CLUSTER_NAME    - Your cluster name
GKE_ZONE            - Your cluster zone
```

## 🔄 Deployment Flow

```
Push to GitHub
     ↓
Train Model
     ↓
Run Tests
     ↓
Build Docker Image
     ↓
Push to GCR
     ↓
Authenticate with GCP
     ↓
Deploy to GKE
     ↓
   ┌────────┴────────┐
   ↓                 ↓
Standard K8s     KServe
```

## 📝 Manual Steps (Alternative)

If you prefer manual setup:

### 1. Create Service Account
```bash
export PROJECT_ID="your-project-id"
export SA_NAME="github-actions-sa"

gcloud iam service-accounts create $SA_NAME \
  --display-name="GitHub Actions SA"
```

### 2. Grant Permissions
```bash
# GCR access
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/storage.admin"

# GKE access
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/container.developer"
```

### 3. Create Key
```bash
gcloud iam service-accounts keys create key.json \
  --iam-account="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

# Base64 encode
cat key.json | base64 -w 0  # Linux
cat key.json | base64       # macOS
```

### 4. Add to GitHub
```bash
gh secret set GCP_SA_KEY --body "$(cat key.json | base64 -w 0)"
gh secret set GCP_PROJECT_ID --body "$PROJECT_ID"
gh secret set GKE_CLUSTER_NAME --body "your-cluster"
gh secret set GKE_ZONE --body "us-central1-a"

# IMPORTANT: Delete local key
rm key.json
```

## ✅ Verify Setup

### 1. Check Secrets
```bash
gh secret list
```

Should show:
```
GCP_SA_KEY
GCP_PROJECT_ID
GKE_CLUSTER_NAME
GKE_ZONE
```

### 2. Test Locally (Optional)
```bash
# Authenticate with service account
gcloud auth activate-service-account --key-file=key.json

# Test GCR access
gcloud auth configure-docker

# Test GKE access
gcloud container clusters get-credentials $CLUSTER_NAME --zone=$ZONE
kubectl get nodes
```

## 🚀 Deploy!

### Automatic (Push to main)
```bash
git add .
git commit -m "Add GKE integration"
git push origin main
```

### Manual Trigger
1. Go to **Actions** tab on GitHub
2. Select **ML Model CI/CD Pipeline (GKE)**
3. Click **Run workflow**
4. Choose deployment type (kserve or standard)
5. Click **Run workflow** button

## 📊 Monitor Deployment

### In GitHub
```bash
# List workflows
gh run list

# Watch live
gh run watch

# View logs
gh run view --log
```

### In GCP Console
1. Go to [GKE Workloads](https://console.cloud.google.com/kubernetes/workload)
2. Select your cluster
3. View deployments and pods

### Using kubectl
```bash
# Set context
gcloud container clusters get-credentials $CLUSTER_NAME --zone=$ZONE

# Check deployment
kubectl get deployments -n ml-models
kubectl get pods -n ml-models
kubectl get services -n ml-models

# View logs
kubectl logs -n ml-models -l app=ml-model --tail=50 -f
```

## 🎯 Access Your Model

### Get Service IP
```bash
kubectl get service ml-model-service -n ml-models

# Wait for EXTERNAL-IP
kubectl get service ml-model-service -n ml-models -w
```

### Test Endpoints
```bash
# Health check
curl http://<EXTERNAL-IP>/health

# Prediction
curl -X POST http://<EXTERNAL-IP>/predict \
  -H "Content-Type: application/json" \
  -d '{"features": [5.1, 3.5, 1.4, 0.2]}'
```

### For KServe
```bash
# Get InferenceService URL
kubectl get inferenceservice iris-model -n ml-models

# Test
curl http://<inference-url>/health
```

## 🐛 Common Issues

### Issue: Permission denied on GCR

```bash
# Grant storage admin
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/storage.admin"
```

### Issue: Cannot connect to GKE

```bash
# Grant container developer
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/container.developer"
```

### Issue: KServe not found

```bash
# Install KServe
kubectl apply -f https://github.com/kserve/kserve/releases/download/v0.11.0/kserve.yaml
```

## 💡 Pro Tips

1. **Use Artifact Registry** instead of GCR (newer, better)
   ```bash
   gcloud artifacts repositories create ml-models \
     --repository-format=docker \
     --location=us-central1
   ```

2. **Enable Workload Identity** for better security
   ```bash
   gcloud container clusters update $CLUSTER_NAME \
     --workload-pool=$PROJECT_ID.svc.id.goog \
     --zone=$ZONE
   ```

3. **Set up Cloud Monitoring**
   ```bash
   gcloud services enable monitoring.googleapis.com
   gcloud services enable logging.googleapis.com
   ```

4. **Enable Binary Authorization** for security
   ```bash
   gcloud services enable binaryauthorization.googleapis.com
   ```

## 📚 Learn More

- [Full GKE Setup Guide](.github/GKE_SETUP.md)
- [Workflows Documentation](.github/WORKFLOWS.md)
- [Main README](README.md)

## 🆘 Get Help

**Issue with setup script?**
```bash
# Check gcloud config
gcloud config list

# Verify cluster
gcloud container clusters describe $CLUSTER_NAME --zone=$ZONE

# Check service account
gcloud iam service-accounts list
```

**Deployment failing?**
```bash
# View workflow logs
gh run view --log

# Check GKE logs
kubectl logs -n ml-models -l app=ml-model

# Describe pod
kubectl describe pod <pod-name> -n ml-models
```

---

**Ready to deploy? Run the setup script and push to main!** 🚀

```bash
# 1. Setup (one time)
cd .github && ./setup-gke.sh

# 2. Deploy!
git push origin main

# 3. Watch it go! 🎉
gh run watch
```
