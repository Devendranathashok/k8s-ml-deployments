# Docker Hub Secret Setup ✅

Your pipeline now automatically creates and uses Docker Hub secrets for image pulling.

## 🔐 What Was Added

### 1. Automatic Secret Creation in Workflow

The workflow now creates a Kubernetes secret with your Docker Hub credentials:

```yaml
- name: Create Docker Hub secret
  run: |
    kubectl create secret docker-registry dockerhub-secret \
      --docker-server=docker.io \
      --docker-username=${{ secrets.DOCKER_USERNAME }} \
      --docker-password=${{ secrets.DOCKER_PASSWORD }} \
      --namespace=ml-models \
      --dry-run=client -o yaml | kubectl apply -f -
```

**Added to:**
- ✅ Standard Kubernetes deployment job
- ✅ KServe deployment job

### 2. Updated Deployments to Use Secret

Both deployment manifests now reference the Docker secret:

#### [k8s/deployment.yaml](k8s/deployment.yaml)
```yaml
spec:
  imagePullSecrets:
  - name: dockerhub-secret
  containers:
  - name: ml-model
    image: ml-model:latest
    imagePullPolicy: Always  # Changed from IfNotPresent
```

#### [k8s/kserve-inferenceservice.yaml](k8s/kserve-inferenceservice.yaml)
```yaml
spec:
  predictor:
    imagePullSecrets:
    - name: dockerhub-secret
    containers:
    - name: kserve-container
      image: ml-model:latest
```

---

## 🎯 Why This Matters

### Without Docker Secret:
- ❌ Can only pull **public** Docker Hub images
- ❌ "ImagePullBackOff" error for private repos
- ❌ Manual secret creation required

### With Docker Secret:
- ✅ Can pull both **public** and **private** images
- ✅ Automatic secret creation and updates
- ✅ Secure credential handling
- ✅ No manual intervention needed

---

## 🚀 How It Works

### Workflow Flow:

```
1. Build & Push Image to Docker Hub
   ↓
2. Authenticate with GCP
   ↓
3. Connect to GKE Cluster
   ↓
4. Create Namespace (ml-models)
   ↓
5. Create/Update Docker Hub Secret ← NEW!
   ↓
6. Deploy to GKE
   ↓
7. Pods pull images using secret ← AUTOMATED!
```

### Secret Details:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: dockerhub-secret
  namespace: ml-models
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: <base64-encoded-credentials>
```

---

## ✅ Verification

### 1. Check Secret Exists

After deployment, verify the secret was created:

```bash
# List secrets
kubectl get secrets -n ml-models

# Should show:
# NAME                TYPE                             DATA   AGE
# dockerhub-secret    kubernetes.io/dockerconfigjson   1      5m
```

### 2. Verify Secret is Used

Check that pods are using the secret:

```bash
# Standard deployment
kubectl get deployment ml-model-deployment -n ml-models -o yaml | grep -A2 imagePullSecrets

# Output:
# imagePullSecrets:
# - name: dockerhub-secret

# KServe
kubectl get inferenceservice iris-model -n ml-models -o yaml | grep -A2 imagePullSecrets

# Output:
# imagePullSecrets:
# - name: dockerhub-secret
```

### 3. Check Pod Status

Pods should pull images successfully:

```bash
kubectl get pods -n ml-models

# Should show Running, not ImagePullBackOff
# NAME                                   READY   STATUS    RESTARTS   AGE
# ml-model-deployment-xxxxx-xxxxx        1/1     Running   0          2m
```

### 4. Describe Pod (Detailed)

```bash
kubectl describe pod -n ml-models <pod-name>

# Should show:
# Events:
#   ...
#   Normal  Pulling    2m    kubelet  Pulling image "username/ml-model:tag"
#   Normal  Pulled     2m    kubelet  Successfully pulled image
#   Normal  Created    2m    kubelet  Created container ml-model
#   Normal  Started    2m    kubelet  Started container ml-model
```

---

## 🔧 Manual Secret Creation (Optional)

If you need to create the secret manually:

```bash
# Create secret
kubectl create secret docker-registry dockerhub-secret \
  --docker-server=docker.io \
  --docker-username=YOUR-USERNAME \
  --docker-password=YOUR-TOKEN \
  --docker-email=YOUR-EMAIL \
  -n ml-models

# Verify
kubectl get secret dockerhub-secret -n ml-models

# View details
kubectl describe secret dockerhub-secret -n ml-models
```

---

## 🔄 Update Secret

The workflow uses `--dry-run=client -o yaml | kubectl apply -f -` which means:
- ✅ Creates secret if it doesn't exist
- ✅ Updates secret if credentials change
- ✅ No error if secret already exists

### Update Docker Hub Credentials

If you change your Docker Hub token:

```bash
# Update GitHub secret
gh secret set DOCKER_PASSWORD --body "new-token-here"

# Next deployment will automatically update the Kubernetes secret
git push origin main
```

---

## 🐛 Troubleshooting

### Issue: ImagePullBackOff

**Check pod events:**
```bash
kubectl describe pod <pod-name> -n ml-models

# Look for:
# Failed to pull image: unauthorized: authentication required
```

**Solutions:**

1. **Verify secret exists:**
   ```bash
   kubectl get secret dockerhub-secret -n ml-models
   ```

2. **Check secret data:**
   ```bash
   kubectl get secret dockerhub-secret -n ml-models -o json | jq -r '.data[".dockerconfigjson"]' | base64 -d | jq
   ```

3. **Verify credentials:**
   ```bash
   # Test Docker Hub login locally
   docker login
   docker pull YOUR-USERNAME/ml-model:latest
   ```

4. **Recreate secret:**
   ```bash
   kubectl delete secret dockerhub-secret -n ml-models
   # Then rerun workflow or create manually
   ```

### Issue: Secret not found

**Error:** `InvalidImageName: spec.template.spec.imagePullSecrets[0].name: "dockerhub-secret" not found`

**Solution:**
```bash
# Ensure workflow step ran successfully
gh run view --log | grep "Docker Hub secret"

# Should show: ✅ Docker Hub secret created/updated

# If not, check workflow logs for errors
```

### Issue: Wrong namespace

**Error:** Secret exists but pods can't find it

**Solution:**
```bash
# Secrets are namespace-scoped
# Ensure secret is in the same namespace as pods

# Check secret namespace
kubectl get secret dockerhub-secret --all-namespaces

# If in wrong namespace, delete and recreate:
kubectl delete secret dockerhub-secret -n <wrong-namespace>
# Rerun workflow to create in correct namespace
```

---

## 📊 Security Best Practices

### ✅ DO:
- Use **access tokens** instead of passwords
- Set token **read-only** permissions if possible
- **Rotate tokens** regularly (every 90 days)
- Store tokens in **GitHub Secrets** only
- Use **separate tokens** for different environments

### ❌ DON'T:
- Hard-code credentials in manifests
- Use your Docker Hub password
- Commit secrets to Git
- Share tokens between projects
- Use tokens with unnecessary permissions

---

## 🔄 Token Rotation

When rotating Docker Hub tokens:

```bash
# 1. Create new token at https://hub.docker.com/settings/security

# 2. Update GitHub secret
gh secret set DOCKER_PASSWORD --body "new-token-here"

# 3. Trigger deployment to update Kubernetes secret
git commit --allow-empty -m "Rotate Docker Hub token"
git push origin main

# 4. Verify new secret works
kubectl get pods -n ml-models
# All pods should be Running

# 5. Delete old token from Docker Hub
# Go to: https://hub.docker.com/settings/security
```

---

## 📚 Files Modified

1. ✅ [.github/workflows/ci-cd.yml](.github/workflows/ci-cd.yml)
   - Added Docker secret creation in standard deployment job
   - Added Docker secret creation in KServe deployment job

2. ✅ [k8s/deployment.yaml](k8s/deployment.yaml)
   - Added `imagePullSecrets`
   - Changed `imagePullPolicy` to `Always`

3. ✅ [k8s/kserve-inferenceservice.yaml](k8s/kserve-inferenceservice.yaml)
   - Added `imagePullSecrets`

---

## 🎓 How imagePullSecrets Work

### Standard Kubernetes:
```yaml
spec:
  imagePullSecrets:        # List of secrets to use
  - name: dockerhub-secret # References the secret name
  containers:
  - image: username/ml-model:tag
    imagePullPolicy: Always  # Always pull (for latest images)
```

### KServe:
```yaml
spec:
  predictor:
    imagePullSecrets:        # At predictor level
    - name: dockerhub-secret
    containers:
    - image: username/ml-model:tag
```

### When Pod is Created:
1. Kubernetes reads `imagePullSecrets`
2. Retrieves Docker credentials from secret
3. Uses credentials to authenticate with Docker Hub
4. Pulls the image
5. Starts the container

---

## 💡 Pro Tips

### 1. Make Repository Public (Easier)

If learning/testing, make your Docker Hub repo public:
- No secrets needed for pulling
- Faster setup
- Still need credentials for **pushing**

```bash
# Workflow still creates secret (doesn't hurt)
# But pods can pull without it
```

### 2. Use Service Account

Alternative to imagePullSecrets (more complex):

```bash
# Attach secret to default service account
kubectl patch serviceaccount default \
  -p '{"imagePullSecrets": [{"name": "dockerhub-secret"}]}' \
  -n ml-models

# Then remove imagePullSecrets from deployment specs
# All pods in namespace will use secret automatically
```

### 3. Multiple Registries

Need to pull from multiple registries? Add more secrets:

```yaml
imagePullSecrets:
- name: dockerhub-secret
- name: gcr-secret
- name: private-registry-secret
```

---

## ✅ Summary

Your pipeline now:
- ✅ Automatically creates Docker Hub secrets
- ✅ Updates secrets when credentials change
- ✅ Uses secrets in all deployments
- ✅ Works with both public and private repos
- ✅ Requires no manual intervention

**Just push to deploy!** 🚀

```bash
git add .
git commit -m "Add Docker Hub secret automation"
git push origin main
```

---

## 📖 Related Documentation

- [DOCKER_HUB_GKE_SETUP.md](DOCKER_HUB_GKE_SETUP.md) - Full pipeline setup
- [FIXES_APPLIED.md](FIXES_APPLIED.md) - Recent fixes
- [Kubernetes Image Pull Secrets](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/)
- [Docker Hub Access Tokens](https://docs.docker.com/docker-hub/access-tokens/)
