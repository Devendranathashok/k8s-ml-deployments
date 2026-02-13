# GKE Integration Guide

Complete guide to integrate Google Kubernetes Engine (GKE) with your GitHub Actions CI/CD pipeline.

## 📋 Prerequisites

- Google Cloud Platform account
- GKE cluster created
- `gcloud` CLI installed
- `kubectl` installed
- GitHub CLI installed (optional, for easier setup)

## 🚀 Quick Setup

### Step 1: Create GCP Service Account

Run the setup script:

**Linux/macOS:**
```bash
cd .github
chmod +x setup-gke.sh
./setup-gke.sh
```

**Windows (PowerShell):**
```powershell
cd .github
.\setup-gke.ps1
```

Or follow the manual steps below.

### Step 2: Manual Setup (Alternative)

#### 1. Set your GCP project
```bash
export PROJECT_ID="your-gcp-project-id"
export CLUSTER_NAME="your-gke-cluster-name"
export ZONE="us-central1-a"  # Your cluster zone
export SA_NAME="github-actions-sa"

gcloud config set project $PROJECT_ID
```

#### 2. Create Service Account
```bash
gcloud iam service-accounts create $SA_NAME \
  --display-name="GitHub Actions Service Account" \
  --description="Service account for GitHub Actions CI/CD"
```

#### 3. Grant Required Permissions
```bash
# Container Registry permissions (for GCR)
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/storage.admin"

# GKE permissions
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/container.developer"

# Optional: Artifact Registry (if using Artifact Registry instead of GCR)
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.writer"
```

#### 4. Create and Download Key
```bash
gcloud iam service-accounts keys create github-actions-key.json \
  --iam-account="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

echo "✅ Service account key created: github-actions-key.json"
```

#### 5. Add GitHub Secrets

**Using GitHub CLI:**
```bash
# Base64 encode the service account key
SA_KEY_BASE64=$(cat github-actions-key.json | base64 -w 0)  # Linux
# SA_KEY_BASE64=$(cat github-actions-key.json | base64)     # macOS

# Set secrets
gh secret set GCP_SA_KEY --body "$SA_KEY_BASE64"
gh secret set GCP_PROJECT_ID --body "$PROJECT_ID"
gh secret set GKE_CLUSTER_NAME --body "$CLUSTER_NAME"
gh secret set GKE_ZONE --body "$ZONE"

echo "✅ Secrets added to GitHub"
```

**Using GitHub Web UI:**
1. Go to your repository on GitHub
2. Navigate to **Settings → Secrets and variables → Actions**
3. Click **New repository secret**
4. Add these secrets:

| Secret Name | Value | How to Get |
|-------------|-------|------------|
| `GCP_SA_KEY` | Base64-encoded service account JSON | `cat github-actions-key.json \| base64` |
| `GCP_PROJECT_ID` | Your GCP project ID | `gcloud config get-value project` |
| `GKE_CLUSTER_NAME` | Your GKE cluster name | Your cluster name |
| `GKE_ZONE` | Your GKE cluster zone | e.g., `us-central1-a` |

#### 6. Clean up local key (Security!)
```bash
# IMPORTANT: Delete the local key file after uploading to GitHub
rm github-actions-key.json

echo "✅ Local key file deleted for security"
```

### Step 3: Update Kubernetes Manifests

Make sure your manifests reference GCR images:

**k8s/deployment.yaml:**
```yaml
containers:
  - name: ml-model
    image: gcr.io/YOUR-PROJECT-ID/ml-model:latest
```

**k8s/kserve-inferenceservice.yaml:**
```yaml
containers:
  - name: kserve-container
    image: gcr.io/YOUR-PROJECT-ID/ml-model:latest
```

### Step 4: Test the Pipeline

```bash
git add .
git commit -m "Add GKE integration"
git push origin main
```

Watch the deployment in GitHub Actions tab! 🚀

## 🏗️ Architecture

```
GitHub Actions
     ↓
Google Cloud Auth
     ↓
Build & Push to GCR
     ↓
Get GKE Credentials
     ↓
Deploy to GKE
     ↓
   ┌────────┴────────┐
   ↓                 ↓
Standard K8s     KServe
```

## 🔐 Required GCP IAM Roles

| Role | Purpose |
|------|---------|
| `roles/storage.admin` | Push/pull images to GCR |
| `roles/container.developer` | Deploy to GKE |
| `roles/artifactregistry.writer` | (Optional) Use Artifact Registry |

### Minimal Permissions (Most Secure)

If you want to follow the principle of least privilege:

```bash
# Custom role with minimal permissions
gcloud iam roles create GitHubActionsMinimal --project=$PROJECT_ID \
  --title="GitHub Actions Minimal" \
  --description="Minimal permissions for GitHub Actions" \
  --permissions="\
container.clusters.get,\
container.clusters.list,\
container.operations.get,\
container.pods.create,\
container.pods.delete,\
container.pods.get,\
container.pods.list,\
container.deployments.create,\
container.deployments.update,\
container.services.create,\
container.services.get,\
storage.buckets.get,\
storage.objects.create,\
storage.objects.delete,\
storage.objects.get,\
storage.objects.list"

# Bind custom role
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="projects/$PROJECT_ID/roles/GitHubActionsMinimal"
```

## 📦 Container Registry Options

### Option 1: Google Container Registry (GCR) - Default

```yaml
env:
  DOCKER_REGISTRY: gcr.io
```

**Image format:** `gcr.io/PROJECT-ID/IMAGE-NAME:TAG`

### Option 2: Artifact Registry (Recommended for new projects)

Create repository:
```bash
gcloud artifacts repositories create ml-models \
  --repository-format=docker \
  --location=us-central1 \
  --description="ML models container images"
```

Update workflow:
```yaml
env:
  DOCKER_REGISTRY: us-central1-docker.pkg.dev
  ARTIFACT_REGISTRY_REPO: ml-models
```

**Image format:** `REGION-docker.pkg.dev/PROJECT-ID/REPO-NAME/IMAGE-NAME:TAG`

## 🌍 Multi-Region Deployment

Deploy to multiple regions:

```yaml
strategy:
  matrix:
    cluster:
      - name: prod-us-central
        zone: us-central1-a
      - name: prod-europe-west
        zone: europe-west1-b

steps:
  - name: Get GKE credentials
    run: |
      gcloud container clusters get-credentials ${{ matrix.cluster.name }} \
        --zone ${{ matrix.cluster.zone }} \
        --project ${{ env.GCP_PROJECT_ID }}
```

## 🔄 Workload Identity (Alternative to Service Account Keys)

For enhanced security, use Workload Identity:

### 1. Enable Workload Identity on cluster
```bash
gcloud container clusters update $CLUSTER_NAME \
  --workload-pool=$PROJECT_ID.svc.id.goog \
  --zone=$ZONE
```

### 2. Update workflow to use Workload Identity
```yaml
- name: Authenticate to Google Cloud
  uses: google-github-actions/auth@v2
  with:
    workload_identity_provider: 'projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/POOL_ID/providers/PROVIDER_ID'
    service_account: 'github-actions-sa@PROJECT_ID.iam.gserviceaccount.com'
```

## 🎯 Environment-Specific Deployments

Deploy to different environments:

```yaml
jobs:
  deploy-staging:
    environment:
      name: staging
    env:
      GKE_CLUSTER_NAME: ${{ secrets.GKE_CLUSTER_NAME_STAGING }}
      K8S_NAMESPACE: ml-models-staging

  deploy-production:
    needs: deploy-staging
    environment:
      name: production
    env:
      GKE_CLUSTER_NAME: ${{ secrets.GKE_CLUSTER_NAME_PROD }}
      K8S_NAMESPACE: ml-models-production
```

## 🔍 Monitoring and Logging

### View Deployment Logs
```bash
# GitHub Actions logs
gh run list
gh run view <run-id> --log

# GKE cluster logs
gcloud logging read "resource.type=k8s_cluster" --limit 50

# Pod logs
kubectl logs -n ml-models -l app=ml-model --tail=100
```

### Cloud Monitoring
```bash
# Enable monitoring
gcloud services enable monitoring.googleapis.com
gcloud services enable logging.googleapis.com

# View metrics
gcloud monitoring dashboards list
```

## 🐛 Troubleshooting

### Issue: Authentication failed

**Error:** `Error: google-github-actions/auth failed with: retry function failed after 1 attempts`

**Solution:**
1. Verify service account key is valid:
   ```bash
   gcloud auth activate-service-account --key-file=github-actions-key.json
   ```
2. Check if key is properly base64 encoded:
   ```bash
   echo "$GCP_SA_KEY" | base64 -d | jq .
   ```
3. Ensure service account has required permissions

### Issue: Cannot push to GCR

**Error:** `denied: Permission "storage.buckets.get" denied`

**Solution:**
```bash
# Grant storage admin role
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/storage.admin"
```

### Issue: Cannot connect to GKE cluster

**Error:** `ERROR: (gcloud.container.clusters.get-credentials) ResponseError: code=403`

**Solution:**
```bash
# Grant GKE developer role
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/container.developer"
```

### Issue: gke-gcloud-auth-plugin not found

**Error:** `E1126 kubectl: error: exec plugin: invalid apiVersion "client.authentication.k8s.io/v1alpha1"`

**Solution:** Already handled in workflow with:
```yaml
- name: Install gke-gcloud-auth-plugin
  run: gcloud components install gke-gcloud-auth-plugin
```

### Issue: KServe not found

**Error:** `error: the server doesn't have a resource type "inferenceservices"`

**Solution:** Install KServe on your GKE cluster:
```bash
# Quick install
kubectl apply -f https://github.com/kserve/kserve/releases/download/v0.11.0/kserve.yaml

# Or use the install script from KServe docs
curl -s "https://raw.githubusercontent.com/kserve/kserve/release-0.11/hack/quick_install.sh" | bash
```

## 💰 Cost Optimization

### 1. Use Preemptible VMs for development
```bash
gcloud container node-pools create dev-pool \
  --cluster=$CLUSTER_NAME \
  --zone=$ZONE \
  --preemptible \
  --num-nodes=3
```

### 2. Enable cluster autoscaling
```bash
gcloud container clusters update $CLUSTER_NAME \
  --enable-autoscaling \
  --min-nodes=1 \
  --max-nodes=10 \
  --zone=$ZONE
```

### 3. Use Artifact Analysis instead of external scanning
```bash
gcloud services enable containeranalysis.googleapis.com
gcloud services enable containerscanning.googleapis.com
```

## 🔒 Security Best Practices

1. **Rotate service account keys regularly**
   ```bash
   # List keys
   gcloud iam service-accounts keys list --iam-account=$SA_EMAIL

   # Delete old keys
   gcloud iam service-accounts keys delete KEY_ID --iam-account=$SA_EMAIL
   ```

2. **Use separate service accounts for different environments**
   - `github-actions-staging-sa`
   - `github-actions-prod-sa`

3. **Enable Binary Authorization**
   ```bash
   gcloud services enable binaryauthorization.googleapis.com
   ```

4. **Use Private GKE clusters**
   ```bash
   gcloud container clusters create $CLUSTER_NAME \
     --enable-private-nodes \
     --enable-private-endpoint \
     --master-ipv4-cidr 172.16.0.0/28
   ```

5. **Enable Shielded GKE nodes**
   ```bash
   gcloud container clusters update $CLUSTER_NAME \
     --enable-shielded-nodes \
     --zone=$ZONE
   ```

## 📚 Additional Resources

- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [GitHub Actions for GCP](https://github.com/google-github-actions)
- [GCR Documentation](https://cloud.google.com/container-registry/docs)
- [Artifact Registry](https://cloud.google.com/artifact-registry/docs)
- [Workload Identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)
- [KServe on GKE](https://kserve.github.io/website/latest/admin/kubernetes_deployment/)

## 🎓 Next Steps

1. ✅ Set up service account with required permissions
2. ✅ Add secrets to GitHub repository
3. ✅ Update workflow configuration
4. ✅ Test deployment pipeline
5. ✅ Set up monitoring and alerting
6. ✅ Configure autoscaling
7. ✅ Enable security features

---

**Your GKE integration is ready! Push to main to trigger your first GKE deployment.** 🚀
