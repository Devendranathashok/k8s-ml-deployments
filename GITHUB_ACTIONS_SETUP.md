# GitHub Actions CI/CD - Quick Start Guide

This guide will help you set up automated CI/CD for your ML model deployment using GitHub Actions.

## 📦 What Was Created

Your repository now includes 4 automated workflows:

1. **`ci-cd.yml`** - Complete CI/CD pipeline (train → test → build → deploy)
2. **`pr-checks.yml`** - Automated testing for pull requests
3. **`manual-retrain.yml`** - On-demand model retraining
4. **`rollback.yml`** - Safe deployment rollback

## 🚀 Quick Setup (5 Minutes)

### Step 1: Install GitHub CLI (if not installed)

**Windows (PowerShell):**
```powershell
winget install --id GitHub.cli
```

**macOS:**
```bash
brew install gh
```

**Linux:**
```bash
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install gh
```

### Step 2: Authenticate with GitHub

```bash
gh auth login
```

Follow the prompts to authenticate.

### Step 3: Run Setup Script

**Windows (PowerShell):**
```powershell
cd .github
.\setup-secrets.ps1
```

**Linux/macOS:**
```bash
cd .github
chmod +x setup-secrets.sh
./setup-secrets.sh
```

The script will guide you through setting up:
- Docker registry credentials
- Kubernetes config
- Optional notifications (Slack, Discord, Email)

### Step 4: Update Configuration

Edit [.github/workflows/ci-cd.yml](.github/workflows/ci-cd.yml) and update:

```yaml
env:
  DOCKER_REGISTRY: docker.io  # Your registry
  IMAGE_NAME: your-username/ml-model  # Your image name
  K8S_NAMESPACE: ml-models  # Your namespace
```

### Step 5: Push and Deploy! 🎉

```bash
git add .
git commit -m "Add GitHub Actions workflows"
git push origin main
```

Watch your pipeline run in the **Actions** tab on GitHub!

## 📋 Required Secrets

The following secrets need to be configured in GitHub:

### Minimum Required Secrets

| Secret Name | Description | How to Get |
|-------------|-------------|------------|
| `DOCKER_USERNAME` | Docker Hub username | Your Docker Hub username |
| `DOCKER_PASSWORD` | Docker Hub access token | [Create token](https://hub.docker.com/settings/security) |
| `KUBE_CONFIG` | Base64-encoded kubeconfig | `cat ~/.kube/config \| base64` |

### Alternative: GitHub Container Registry (No extra secrets!)

If you use GitHub Container Registry (ghcr.io), you don't need Docker credentials!

Update [.github/workflows/ci-cd.yml](.github/workflows/ci-cd.yml):

```yaml
env:
  DOCKER_REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}
```

And in the login step:
```yaml
- name: Log in to Container Registry
  uses: docker/login-action@v3
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}
```

## 🎯 Usage Examples

### Automatic Deployment

Just push to main:
```bash
git push origin main
```

Automatically:
1. ✅ Trains the model
2. ✅ Runs tests
3. ✅ Builds Docker image
4. ✅ Deploys to Kubernetes with KServe

### Manual Deployment

1. Go to **Actions** tab in GitHub
2. Select **ML Model CI/CD Pipeline**
3. Click **Run workflow**
4. Choose deployment type (kserve or standard)
5. Click **Run workflow**

### Retrain Model

1. Go to **Actions** tab
2. Select **Manual Model Retraining**
3. Click **Run workflow**
4. Configure options:
   - Dataset version: `iris-v2`
   - Auto-deploy: `true`
   - Deployment type: `kserve`
5. Click **Run workflow**

### Rollback Deployment

If something goes wrong:

1. Go to **Actions** tab
2. Select **Rollback Deployment**
3. Click **Run workflow**
4. Choose deployment type and revision
5. Click **Run workflow**

## 🔄 Workflow Triggers

| Workflow | Auto Trigger | Manual Trigger |
|----------|--------------|----------------|
| CI/CD Pipeline | Push to `main` or `develop` | ✅ Yes |
| PR Checks | Pull requests to `main` | ❌ No |
| Manual Retrain | Never | ✅ Yes |
| Rollback | Never | ✅ Yes |

## 📊 Monitoring

### View Workflow Status

**In GitHub:**
- Go to **Actions** tab
- See all workflow runs
- Click on a run to see details

**Using GitHub CLI:**
```bash
# List recent runs
gh run list

# View specific run
gh run view <run-id>

# Watch a running workflow
gh run watch
```

### Check Deployment Status

```bash
# Standard Kubernetes
kubectl get deployments
kubectl get pods

# KServe
kubectl get inferenceservices -n ml-models
kubectl get pods -n ml-models
```

## 🐛 Troubleshooting

### Issue: Workflow fails at Docker login

**Solution:**
1. Verify secrets are set: `gh secret list`
2. For Docker Hub, use access token (not password)
3. Check token has push permissions

### Issue: Workflow fails at kubectl deploy

**Solution:**
1. Verify KUBE_CONFIG is base64 encoded
2. Test locally: `echo $KUBE_CONFIG | base64 -d | kubectl --kubeconfig=/dev/stdin get nodes`
3. Check service account permissions

### Issue: KServe InferenceService not ready

**Solution:**
1. Verify KServe is installed: `kubectl get pods -n kserve`
2. Check CRD exists: `kubectl get crd inferenceservices.serving.kserve.io`
3. View status: `kubectl describe inferenceservice iris-model -n ml-models`

### Issue: Image pull error

**Solution:**
1. Verify image was pushed: Check container registry
2. Check image name in manifest matches pushed image
3. Add image pull secret if using private registry

## 📚 Advanced Configuration

### Multi-Environment Deployment

Add staging environment before production:

```yaml
# In ci-cd.yml
deploy-staging:
  name: Deploy to Staging
  environment: staging
  # ... deployment steps

deploy-production:
  name: Deploy to Production
  needs: deploy-staging
  environment: production
  # ... deployment steps
```

### Add Slack Notifications

1. Create Slack webhook: https://api.slack.com/messaging/webhooks
2. Add secret: `gh secret set SLACK_WEBHOOK --body "https://hooks.slack.com/..."`
3. Add to workflow:

```yaml
- name: Notify Slack
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
  if: always()
```

### Add Performance Tests

```yaml
performance-test:
  needs: deploy-kserve
  runs-on: ubuntu-latest
  steps:
    - name: Load test
      run: |
        kubectl run hey --image=williamyeh/hey --rm -i --restart=Never -- \
          -n 1000 -c 10 http://iris-model.ml-models/predict
```

## 📖 Full Documentation

For detailed information, see:
- [Complete Workflows Guide](.github/WORKFLOWS.md)
- [Secrets Template](.github/secrets.template.env)
- [Main README](README.md)

## 🎓 Learning Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Docker Build Push Action](https://github.com/docker/build-push-action)
- [Kubernetes GitHub Actions](https://github.com/Azure/k8s-deploy)
- [KServe Documentation](https://kserve.github.io/website/)

## 💡 Tips

1. **Use branch protection** - Require PR checks to pass before merging
2. **Monitor costs** - Check GitHub Actions minutes usage
3. **Cache dependencies** - Workflows use caching for faster builds
4. **Test locally** - Use [act](https://github.com/nektos/act) to test workflows locally
5. **Version your models** - Use semantic versioning for model releases

## 🤝 Getting Help

- Check [WORKFLOWS.md](.github/WORKFLOWS.md) for detailed troubleshooting
- Review workflow logs in GitHub Actions tab
- Check Kubernetes logs: `kubectl logs -n ml-models <pod-name>`
- Open an issue in your repository

---

**Next Steps:**
1. ✅ Complete the setup steps above
2. ✅ Push to trigger your first deployment
3. ✅ Monitor in the Actions tab
4. ✅ Test your deployed model

Happy deploying! 🚀
