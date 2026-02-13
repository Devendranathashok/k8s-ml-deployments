# GitHub Actions CI/CD Workflows

Automated pipelines for training, testing, building, and deploying your ML model to Kubernetes.

## 📋 Workflows Overview

### 1. **CI/CD Pipeline** (`ci-cd.yml`)
Complete automation pipeline that:
- ✅ Trains the ML model
- ✅ Runs tests
- ✅ Builds and pushes Docker image
- ✅ Deploys to Kubernetes (Standard or KServe)

**Triggers:**
- Push to `main` or `develop` branches
- Pull requests to `main`
- Manual dispatch with deployment type selection

### 2. **PR Checks** (`pr-checks.yml`)
Validates pull requests before merge:
- ✅ Code linting and formatting
- ✅ Model training test
- ✅ API endpoint tests
- ✅ Docker build test
- ✅ Kubernetes manifest validation

**Triggers:**
- Pull requests to `main` or `develop`

### 3. **Manual Model Retraining** (`manual-retrain.yml`)
On-demand model retraining:
- ✅ Train model with custom dataset version
- ✅ Generate model metrics
- ✅ Upload artifacts
- ✅ Optional automatic deployment trigger

**Triggers:**
- Manual workflow dispatch

### 4. **Rollback** (`rollback.yml`)
Safe rollback mechanism:
- ✅ Rollback to previous deployment
- ✅ Rollback to specific revision
- ✅ Works with both Standard K8s and KServe

**Triggers:**
- Manual workflow dispatch

---

## 🔐 Required Secrets

Configure these secrets in your GitHub repository: **Settings → Secrets and variables → Actions → New repository secret**

### For Docker Registry

#### Option A: Docker Hub
```
DOCKER_USERNAME=your-dockerhub-username
DOCKER_PASSWORD=your-dockerhub-access-token
```

#### Option B: GitHub Container Registry (GHCR)
```
GHCR_USERNAME=${{ github.actor }}
DOCKER_PASSWORD=${{ secrets.GITHUB_TOKEN }}
```

Update in `ci-cd.yml`:
```yaml
env:
  DOCKER_REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}
```

#### Option C: Google Container Registry (GCR)
```
GCR_SERVICE_ACCOUNT_KEY=<base64-encoded-service-account-json>
```

Update in `ci-cd.yml`:
```yaml
- name: Log in to GCR
  uses: docker/login-action@v3
  with:
    registry: gcr.io
    username: _json_key
    password: ${{ secrets.GCR_SERVICE_ACCOUNT_KEY }}
```

### For Kubernetes Deployment

```
KUBE_CONFIG=<base64-encoded-kubeconfig>
```

**How to generate KUBE_CONFIG:**

```bash
# Get your kubeconfig (usually ~/.kube/config)
cat ~/.kube/config | base64 -w 0

# On macOS:
cat ~/.kube/config | base64

# Copy the output and add as KUBE_CONFIG secret
```

**⚠️ Important:** Make sure your kubeconfig has the necessary permissions to deploy to your cluster.

---

## 🚀 Quick Setup Guide

### Step 1: Fork/Clone Repository

```bash
git clone https://github.com/your-username/ml-k8s-deployment.git
cd ml-k8s-deployment
```

### Step 2: Configure Secrets

1. Go to your GitHub repository
2. Navigate to **Settings → Secrets and variables → Actions**
3. Click **New repository secret**
4. Add the required secrets listed above

### Step 3: Update Configuration

Edit `.github/workflows/ci-cd.yml`:

```yaml
env:
  DOCKER_REGISTRY: docker.io  # Change to your registry
  IMAGE_NAME: your-username/ml-model  # Change to your image name
  K8S_NAMESPACE: ml-models  # Change to your namespace
```

### Step 4: Update Kubernetes Manifests

Update the image references in your manifests to match your registry:

**k8s/deployment.yaml:**
```yaml
containers:
  - name: ml-model
    image: your-registry/your-username/ml-model:latest
```

**k8s/kserve-inferenceservice.yaml:**
```yaml
containers:
  - name: kserve-container
    image: your-registry/your-username/ml-model:latest
```

### Step 5: Push to GitHub

```bash
git add .
git commit -m "Configure GitHub Actions workflows"
git push origin main
```

The CI/CD pipeline will automatically trigger!

---

## 📖 Usage Examples

### Automatic Deployment (Push to main)

```bash
git checkout main
git add .
git commit -m "Update model training script"
git push origin main
```

This will automatically:
1. Train the model
2. Run tests
3. Build Docker image
4. Deploy to Kubernetes with KServe (default)

### Manual Deployment with Specific Type

1. Go to **Actions** tab in GitHub
2. Select **ML Model CI/CD Pipeline**
3. Click **Run workflow**
4. Choose deployment type (kserve or standard)
5. Click **Run workflow**

### Pull Request Testing

```bash
git checkout -b feature/new-model
# Make changes
git add .
git commit -m "Add new model"
git push origin feature/new-model
```

Create a PR on GitHub - automated tests will run automatically.

### Manual Model Retraining

1. Go to **Actions** tab
2. Select **Manual Model Retraining**
3. Click **Run workflow**
4. Fill in options:
   - Dataset version: `iris-v2` (or your version)
   - Trigger deployment: `true/false`
   - Deployment type: `kserve/standard/none`
5. Click **Run workflow**

### Rollback Deployment

1. Go to **Actions** tab
2. Select **Rollback Deployment**
3. Click **Run workflow**
4. Choose:
   - Deployment type: `kserve` or `standard`
   - Revision: Leave empty for previous, or specify commit SHA
5. Click **Run workflow**

---

## 🏗️ Workflow Architecture

```
┌─────────────────┐
│  Push to main   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Train Model    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Run Tests     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Build & Push    │
│  Docker Image   │
└────────┬────────┘
         │
         ▼
    ┌────┴────┐
    │         │
    ▼         ▼
┌────────┐ ┌────────┐
│Standard│ │KServe  │
│  K8s   │ │Deploy  │
└────────┘ └────────┘
```

---

## 🔧 Customization

### Add Slack Notifications

Add to the `notify` job in `ci-cd.yml`:

```yaml
- name: Send Slack notification
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    text: 'Deployment completed!'
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
  if: always()
```

Then add `SLACK_WEBHOOK` secret.

### Add Email Notifications

```yaml
- name: Send email notification
  uses: dawidd6/action-send-mail@v3
  with:
    server_address: smtp.gmail.com
    server_port: 465
    username: ${{ secrets.EMAIL_USERNAME }}
    password: ${{ secrets.EMAIL_PASSWORD }}
    subject: Deployment Status
    body: Deployment completed with status ${{ job.status }}
    to: your-email@example.com
    from: GitHub Actions
```

### Add Multiple Environments

Update `ci-cd.yml` to deploy to staging first:

```yaml
deploy-staging:
  name: Deploy to Staging
  runs-on: ubuntu-latest
  needs: build-and-push
  environment:
    name: staging
  # ... deployment steps

deploy-production:
  name: Deploy to Production
  runs-on: ubuntu-latest
  needs: deploy-staging
  environment:
    name: production
  # ... deployment steps
```

### Add Model Performance Tests

Add to `ci-cd.yml` after deployment:

```yaml
performance-test:
  name: Run Performance Tests
  needs: deploy-kserve
  runs-on: ubuntu-latest
  steps:
    - name: Load test
      run: |
        kubectl run load-test --image=williamyeh/hey --rm -i --restart=Never -- \
          -n 1000 -c 10 http://iris-model.ml-models.svc.cluster.local/predict
```

---

## 🐛 Troubleshooting

### Workflow fails at "Log in to Container Registry"

**Issue:** Authentication failed

**Solution:**
1. Verify your registry credentials in GitHub Secrets
2. For Docker Hub, use an access token, not your password
3. For GHCR, ensure `GITHUB_TOKEN` has write permissions

### Workflow fails at "Configure kubectl"

**Issue:** Invalid kubeconfig

**Solution:**
1. Verify your KUBE_CONFIG secret is base64-encoded
2. Test locally: `echo $KUBE_CONFIG | base64 -d | kubectl --kubeconfig=/dev/stdin get nodes`
3. Ensure the service account has necessary permissions

### Deployment times out

**Issue:** Pods not starting

**Solution:**
1. Check pod logs: `kubectl logs -n ml-models <pod-name>`
2. Verify image exists in registry
3. Check resource limits in deployment manifest
4. Ensure nodes have enough resources

### KServe InferenceService not ready

**Issue:** InferenceService stuck in not ready state

**Solution:**
1. Check if KServe is installed: `kubectl get pods -n kserve`
2. Verify CRD exists: `kubectl get crd inferenceservices.serving.kserve.io`
3. Check InferenceService status: `kubectl describe inferenceservice iris-model -n ml-models`
4. Review pod events: `kubectl get events -n ml-models`

### Model file not found in container

**Issue:** Model files missing in Docker image

**Solution:**
1. Ensure model is trained before Docker build
2. Check artifact upload/download steps
3. Verify Dockerfile COPY statements
4. Check `.dockerignore` doesn't exclude model files

---

## 📊 Monitoring Deployments

### View Workflow Runs

```bash
# Using GitHub CLI
gh run list
gh run view <run-id>
gh run watch <run-id>
```

### Check Deployment Status

```bash
# For standard K8s
kubectl get deployments
kubectl rollout status deployment/ml-model-deployment

# For KServe
kubectl get inferenceservices -n ml-models
kubectl get pods -n ml-models
```

### View Logs

```bash
# GitHub Actions logs
gh run view <run-id> --log

# Kubernetes logs
kubectl logs -l app=ml-model
kubectl logs -n ml-models -l serving.kserve.io/inferenceservice=iris-model
```

---

## 🎯 Best Practices

1. **Use Semantic Versioning** for model versions
2. **Run PR checks** before merging to main
3. **Test in staging** before production deployment
4. **Monitor model performance** after deployment
5. **Keep secrets secure** - never commit them
6. **Use branch protection** rules for main branch
7. **Review deployment logs** after each deployment
8. **Set up alerts** for failed deployments
9. **Document model changes** in commit messages
10. **Regularly update dependencies** and base images

---

## 📚 Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [KServe Documentation](https://kserve.github.io/website/)
- [Docker Documentation](https://docs.docker.com/)

---

## 🤝 Contributing

To add new workflows or improve existing ones:

1. Create a new branch: `git checkout -b feature/new-workflow`
2. Make your changes
3. Test locally with `act` (GitHub Actions local runner)
4. Submit a pull request

---

## 📝 License

These workflows are part of the ml-k8s-deployment project and follow the same MIT License.
