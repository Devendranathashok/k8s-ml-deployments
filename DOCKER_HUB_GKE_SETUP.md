# Docker Hub + GKE Deployment Setup

Your unified CI/CD pipeline now uses **Docker Hub for images** and **GKE for deployment**.

## ✅ What Changed

- ✅ **Single workflow**: Only [ci-cd.yml](.github/workflows/ci-cd.yml) (removed ci-cd-gke.yml)
- ✅ **Docker Hub**: Images pushed to `docker.io/YOUR-USERNAME/ml-model`
- ✅ **GKE Deployment**: Still deploys to your GKE cluster
- ✅ **Simplified**: One workflow to rule them all!

## 🔐 Required Secrets

You need **6 secrets** total:

| Secret | Purpose | How to Get |
|--------|---------|------------|
| `DOCKER_USERNAME` | Docker Hub username | Your Docker Hub username |
| `DOCKER_PASSWORD` | Docker Hub access token | https://hub.docker.com/settings/security |
| `GCP_SA_KEY` | GCP service account | Run setup script |
| `GCP_PROJECT_ID` | Your GCP project | `celestial-ridge-481607-g` |
| `GKE_CLUSTER_NAME` | Your cluster name | `gcloud container clusters list` |
| `GKE_ZONE` | Your cluster zone | `gcloud container clusters list` |

---

## 🚀 Quick Setup (5 Minutes)

### Step 1: Get Docker Hub Access Token

1. Go to https://hub.docker.com/settings/security
2. Click **New Access Token**
3. Name: `github-actions`
4. Permissions: **Read, Write, Delete**
5. Click **Generate**
6. **Copy the token** (you won't see it again!)

### Step 2: Add Docker Hub Secrets

**Using GitHub CLI (Fastest):**

```bash
# Navigate to your repo
cd c:/Users/ashok/ml-k8s-deployment

# Authenticate if needed
gh auth login

# Add Docker Hub secrets
gh secret set DOCKER_USERNAME --body "your-dockerhub-username"
gh secret set DOCKER_PASSWORD --body "your-access-token-here"
```

**Using GitHub Web Interface:**

1. Go to: `https://github.com/YOUR-USERNAME/ml-k8s-deployment/settings/secrets/actions`
2. Click **New repository secret**
3. Add:
   ```
   Name: DOCKER_USERNAME
   Value: your-dockerhub-username
   ```
4. Click **Add secret**
5. Repeat for:
   ```
   Name: DOCKER_PASSWORD
   Value: your-docker-hub-access-token
   ```

### Step 3: Add GCP/GKE Secrets

Run the automated setup script:

```bash
cd .github
chmod +x setup-gke.sh
./setup-gke.sh
```

Or add manually:

```bash
# Get your cluster info
gcloud container clusters list

# Add secrets
gh secret set GCP_PROJECT_ID --body "celestial-ridge-481607-g"
gh secret set GKE_CLUSTER_NAME --body "your-cluster-name"
gh secret set GKE_ZONE --body "us-central1-a"

# Add service account key (after creating it)
gh secret set GCP_SA_KEY --body "$(cat key.json | base64 -w 0)"
```

### Step 4: Verify All Secrets

```bash
gh secret list
```

Should show:
```
DOCKER_USERNAME     ✅
DOCKER_PASSWORD     ✅
GCP_PROJECT_ID      ✅
GCP_SA_KEY          ✅
GKE_CLUSTER_NAME    ✅
GKE_ZONE            ✅
```

---

## 🎯 Update Your Docker Hub Username

Edit [.github/workflows/ci-cd.yml](.github/workflows/ci-cd.yml) line 20:

```yaml
env:
  DOCKER_REGISTRY: docker.io
  DOCKER_USERNAME: ${{ secrets.DOCKER_USERNAME }}  # ✅ Already correct
  IMAGE_NAME: ml-model
```

**No changes needed!** It already uses the secret. ✅

---

## 📦 Deployment Flow

```
Push to GitHub
     ↓
Train ML Model
     ↓
Run Tests
     ↓
Build Docker Image
     ↓
Push to Docker Hub (docker.io/username/ml-model)
     ↓
Authenticate with GCP
     ↓
Deploy to GKE
     ↓
   ┌────────┴────────┐
   ↓                 ↓
Standard K8s     KServe
```

---

## 🚀 Deploy Now!

### Automatic Deployment

```bash
git add .
git commit -m "Configure Docker Hub + GKE pipeline"
git push origin main
```

Watch it deploy: `https://github.com/YOUR-USERNAME/ml-k8s-deployment/actions`

### Manual Deployment

1. Go to **Actions** tab on GitHub
2. Select **ML Model CI/CD Pipeline**
3. Click **Run workflow**
4. Choose:
   - Branch: `main`
   - Deployment type: `kserve` or `standard`
5. Click **Run workflow**

---

## 🔍 Monitor Deployment

### GitHub Actions

```bash
# List runs
gh run list

# Watch live
gh run watch

# View logs
gh run view --log
```

### Docker Hub

Check your images at:
```
https://hub.docker.com/r/YOUR-USERNAME/ml-model/tags
```

### GKE Cluster

```bash
# Get cluster credentials
gcloud container clusters get-credentials YOUR-CLUSTER --zone=YOUR-ZONE

# Check deployment
kubectl get all -n ml-models

# View logs
kubectl logs -n ml-models -l app=ml-model -f

# Get external IP
kubectl get service ml-model-service -n ml-models
```

---

## 🌐 Access Your Deployed Model

### Get Service Endpoint

```bash
# Standard Kubernetes deployment
kubectl get service ml-model-service -n ml-models

# Wait for EXTERNAL-IP
kubectl get service ml-model-service -n ml-models -w
```

### Test Your Model

```bash
# Get external IP
export EXTERNAL_IP=$(kubectl get service ml-model-service -n ml-models -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Health check
curl http://$EXTERNAL_IP/health

# Make a prediction
curl -X POST http://$EXTERNAL_IP/predict \
  -H "Content-Type: application/json" \
  -d '{"features": [5.1, 3.5, 1.4, 0.2]}'
```

### For KServe Deployment

```bash
# Get InferenceService status
kubectl get inferenceservice iris-model -n ml-models

# Get service URL
kubectl get inferenceservice iris-model -n ml-models -o jsonpath='{.status.url}'
```

---

## 🐛 Troubleshooting

### Issue: Docker Hub authentication failed

**Error:** `denied: requested access to the resource is denied`

**Solution:**
1. Verify username is correct: `gh secret list`
2. Create new access token at https://hub.docker.com/settings/security
3. Make sure token has **Read & Write** permissions
4. Update secret: `gh secret set DOCKER_PASSWORD --body "new-token"`

### Issue: Cannot connect to GKE

**Error:** `Error: google-github-actions/auth failed`

**Solution:**
```bash
# Verify GCP secrets
gh secret list | grep -E "GCP|GKE"

# Re-run setup script
cd .github && ./setup-gke.sh
```

### Issue: Image pull error in GKE

**Error:** `Failed to pull image "username/ml-model:tag"`

**Solution:**

If using private Docker Hub repository, add image pull secret to GKE:

```bash
# Create Docker Hub secret in GKE
kubectl create secret docker-registry dockerhub-secret \
  --docker-server=docker.io \
  --docker-username=YOUR-USERNAME \
  --docker-password=YOUR-TOKEN \
  --docker-email=YOUR-EMAIL \
  -n ml-models

# Update deployment to use secret
kubectl patch serviceaccount default \
  -p '{"imagePullSecrets": [{"name": "dockerhub-secret"}]}' \
  -n ml-models
```

Or make your Docker Hub repository **public** (recommended for learning).

### Issue: Workflow not triggering

**Solution:**
```bash
# Check workflow file syntax
gh workflow view

# Manually trigger
gh workflow run "ML Model CI/CD Pipeline"
```

---

## 💡 Pro Tips

### 1. Make Repository Public (Easier)

Public Docker Hub repositories don't need pull secrets in GKE:

1. Go to https://hub.docker.com/repository/docker/YOUR-USERNAME/ml-model
2. Click **Settings**
3. Make it **Public**

### 2. Use Docker Hub Caching

Already configured in workflow:
```yaml
cache-from: type=gha
cache-to: type=gha,mode=max
```

Subsequent builds will be much faster! ⚡

### 3. Enable Docker Hub Vulnerability Scanning

Free for public repositories:
1. Go to repository settings
2. Enable **Vulnerability scanning**
3. View results in **Tags** tab

### 4. Set Up Notifications

Add to [.github/workflows/ci-cd.yml](.github/workflows/ci-cd.yml):

```yaml
- name: Notify on Slack
  if: always()
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

---

## 📊 Image Tags

Your images will be tagged as:

```
docker.io/YOUR-USERNAME/ml-model:latest              # Latest from main
docker.io/YOUR-USERNAME/ml-model:main-a1b2c3d        # Branch + commit SHA
docker.io/YOUR-USERNAME/ml-model:develop-x7y8z9      # Develop branch
```

View all tags:
```bash
docker pull YOUR-USERNAME/ml-model:latest
docker images | grep ml-model
```

---

## 🎓 What's Next?

1. ✅ **Set up secrets** (Docker Hub + GCP)
2. ✅ **Push to trigger deployment**
3. ✅ **Monitor in Actions tab**
4. ✅ **Test deployed model**
5. ✅ **Set up monitoring** (Prometheus/Grafana)
6. ✅ **Add alerts** (Slack/Discord)

---

## 📚 Related Documentation

- [GKE Setup Guide](.github/GKE_SETUP.md)
- [Workflows Documentation](.github/WORKFLOWS.md)
- [Main README](README.md)

---

## 🆘 Getting Help

**Quick diagnostic:**

```bash
# Check secrets
gh secret list

# Test Docker Hub login locally
docker login
docker tag ml-model:latest YOUR-USERNAME/ml-model:test
docker push YOUR-USERNAME/ml-model:test

# Test GKE connection
gcloud container clusters get-credentials YOUR-CLUSTER --zone=YOUR-ZONE
kubectl get nodes
```

**Common commands:**

```bash
# View workflow runs
gh run list

# View specific run
gh run view <run-id>

# Rerun failed workflow
gh run rerun <run-id>

# View logs
gh run view <run-id> --log
```

---

**You're all set! 🎉**

Push to main to trigger your first deployment:

```bash
git add .
git commit -m "Configure Docker Hub + GKE deployment"
git push origin main
```

Watch the magic happen: `gh run watch` ✨
