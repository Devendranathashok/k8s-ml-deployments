# Fixes Applied ✅

## Issues Found and Fixed

### 🐛 Issue 1: Missing Image in Deployment
**Error:**
```
The Deployment "ml-model-deployment" is invalid:
spec.template.spec.containers[0].image: Required value
```

**Root Cause:**
The workflow was referencing the wrong output step for the image tag.

**Fix:**
```yaml
# Before (WRONG)
outputs:
  image_tag: ${{ steps.meta.outputs.primary_tag }}  # ❌ meta doesn't have primary_tag

# After (CORRECT)
outputs:
  image_tag: ${{ steps.primary.outputs.primary_tag }}  # ✅ primary step has primary_tag
```

**File Changed:** [.github/workflows/ci-cd.yml](.github/workflows/ci-cd.yml#L120)

---

### 🐛 Issue 2: KServe "PORT" Reserved Variable
**Error:**
```
"PORT" is a reserved environment variable: spec.template.spec.containers[0].env[0].name
```

**Root Cause:**
KServe/Knative reserves the `PORT` environment variable and sets it automatically.

**Fix:**
Removed `PORT` from environment variables in KServe InferenceService. The app will:
- Use port 5000 (default in code: `port = int(os.environ.get('PORT', 5000))`)
- KServe will expose this correctly via `containerPort: 5000`

**File Changed:** [k8s/kserve-inferenceservice.yaml](k8s/kserve-inferenceservice.yaml#L21-L26)

**Before:**
```yaml
env:
  - name: PORT          # ❌ Reserved by KServe
    value: "5000"
  - name: STORAGE_URI
    value: "pvc://model-pvc/model"
```

**After:**
```yaml
env:
  - name: MODEL_NAME    # ✅ Safe variable
    value: "iris-model"
```

---

## Changes Summary

### Files Modified

1. **[.github/workflows/ci-cd.yml](.github/workflows/ci-cd.yml)**
   - Fixed image tag output reference (line 120)
   - Added debug logging for image updates

2. **[k8s/kserve-inferenceservice.yaml](k8s/kserve-inferenceservice.yaml)**
   - Removed `PORT` environment variable
   - Added `MODEL_NAME` environment variable
   - Added `name: http1` to port specification for better KServe compatibility

---

## ✅ Verification

### Check Image Tag is Set

The workflow now includes debug output:

```bash
📦 Using image: username/ml-model:main-a1b2c3d
✅ Updated deployment.yaml:
        image: username/ml-model:main-a1b2c3d
```

You'll see this in the GitHub Actions logs.

### Check KServe Port Configuration

```yaml
ports:
  - containerPort: 5000
    protocol: TCP
    name: http1           # ✅ Named port for KServe
env:
  - name: MODEL_NAME      # ✅ No PORT variable
    value: "iris-model"
```

---

## 🚀 Next Steps

### 1. Commit and Push

```bash
git add .
git commit -m "Fix: Docker image tag and KServe PORT variable"
git push origin main
```

### 2. Monitor Deployment

```bash
# Watch workflow
gh run watch

# Check deployment
kubectl get all -n ml-models

# Check KServe InferenceService
kubectl get inferenceservice iris-model -n ml-models
```

### 3. Verify Success

**Standard Deployment:**
```bash
kubectl get deployment ml-model-deployment -n ml-models
kubectl get pods -n ml-models
```

**KServe Deployment:**
```bash
# Should show Ready=True
kubectl get inferenceservice iris-model -n ml-models

# Should have no errors
kubectl describe inferenceservice iris-model -n ml-models
```

---

## 🔍 Troubleshooting

### If deployment still fails:

**1. Check image was pushed to Docker Hub:**
```bash
# View workflow logs
gh run view --log | grep "Push to Docker Hub"

# Check Docker Hub
# Go to: https://hub.docker.com/r/YOUR-USERNAME/ml-model/tags
```

**2. Verify image tag in manifest:**
```bash
# Should NOT be "ml-model:latest"
kubectl get deployment ml-model-deployment -n ml-models -o yaml | grep image:
```

**3. Check image pull:**
```bash
# If seeing ImagePullBackOff
kubectl describe pod -n ml-models <pod-name>

# If private repo, add pull secret:
kubectl create secret docker-registry dockerhub-secret \
  --docker-server=docker.io \
  --docker-username=YOUR-USERNAME \
  --docker-password=YOUR-TOKEN \
  -n ml-models
```

**4. Check KServe events:**
```bash
# Should have no validation errors
kubectl describe inferenceservice iris-model -n ml-models

# Check KServe controller logs
kubectl logs -n kserve -l control-plane=kserve-controller-manager
```

---

## 📊 Expected Workflow Output

### Build Job
```
✅ Logging in to Docker Hub
✅ Building image
✅ Pushing image
📦 Image: username/ml-model:main-a1b2c3d
```

### Deploy Job
```
✅ Getting GKE credentials
✅ Connected to cluster
📦 Using image: username/ml-model:main-a1b2c3d
✅ Updated deployment.yaml:
        image: username/ml-model:main-a1b2c3d
✅ Deployment applied
✅ Rollout successful
```

---

## 💡 Key Learnings

1. **Always use correct step IDs** in workflow outputs
2. **KServe reserves certain env variables** (PORT, K_SERVICE, etc.)
3. **Named ports** (`name: http1`) help KServe identify HTTP endpoints
4. **Debug logging** makes troubleshooting much easier

---

## 📚 Related Files

- [ci-cd.yml](.github/workflows/ci-cd.yml) - Main workflow
- [kserve-inferenceservice.yaml](k8s/kserve-inferenceservice.yaml) - KServe config
- [deployment.yaml](k8s/deployment.yaml) - Standard K8s deployment
- [app.py](app.py) - Flask application (uses PORT from env, defaults to 5000)

---

**All fixes applied! Push to main to test the updated pipeline.** 🚀

```bash
git add .
git commit -m "Fix deployment image tag and KServe PORT issue"
git push origin main
```
