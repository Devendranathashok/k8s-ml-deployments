# Image Tag Troubleshooting Guide 🔍

## Problem: IMAGE_TAG is empty

If you're seeing `❌ ERROR: IMAGE_TAG is empty!`, this guide will help you fix it.

---

## 🔍 Added Debug Steps

The workflow now has extensive debugging to show you **exactly** where the problem is:

### Build Job Debugging:
```yaml
1. Check inputs
   → Shows DOCKER_USER, IMAGE_NAME, SHORT_SHA, BRANCH_NAME

2. Generate tags
   → Shows generated PRIMARY_TAG and LATEST_TAG

3. Write to GITHUB_OUTPUT
   → Confirms output was written

4. Verify job outputs
   → Confirms output can be read within same job
```

### Deploy Job Debugging:
```yaml
1. Debug job inputs
   → Shows image_tag received from build job
   → Fails fast if empty

2. Update image in deployment
   → Validates IMAGE_TAG not empty
   → Shows actual replacement
   → Verifies replacement succeeded
```

---

## 📊 What You'll See in Logs

### ✅ Success Case:

**Build Job:**
```
🔍 Debug: Checking inputs...
  DOCKER_USER: myusername
  IMAGE_NAME: ml-model
  SHORT_SHA: abc1234
  BRANCH_NAME: main

📦 Generated tags:
  Primary: myusername/ml-model:main-abc1234
  Latest: myusername/ml-model:latest

✅ Tags written to GITHUB_OUTPUT

🔍 Verifying job outputs...
  primary_tag: myusername/ml-model:main-abc1234
  image_digest: sha256:...
✅ Job outputs verified
```

**Deploy Job:**
```
🔍 Debug: Checking received job outputs...
  image_tag from build: myusername/ml-model:main-abc1234
  image_digest from build: sha256:...
✅ Received image tag successfully

📦 Using image: myusername/ml-model:main-abc1234
✅ Updated deployment.yaml:
        image: myusername/ml-model:main-abc1234
🔍 Verifying image field is set:
✅ Image successfully updated
```

### ❌ Error Cases:

#### Case 1: DOCKER_USERNAME not set
```
🔍 Debug: Checking inputs...
  DOCKER_USER:
  IMAGE_NAME: ml-model
❌ ERROR: DOCKER_USERNAME secret is not set!
```

**Fix:**
```bash
gh secret set DOCKER_USERNAME --body "your-dockerhub-username"
```

#### Case 2: IMAGE_NAME not set
```
🔍 Debug: Checking inputs...
  DOCKER_USER: myusername
  IMAGE_NAME:
❌ ERROR: IMAGE_NAME env var is not set!
```

**Fix:** Check workflow file env section has:
```yaml
env:
  IMAGE_NAME: ml-model
```

#### Case 3: Output not received in deploy job
```
🔍 Debug: Checking received job outputs...
  image_tag from build:
❌ ERROR: No image_tag received from build-and-push job!
```

**Fix:** Check build job succeeded:
```bash
gh run view --log | grep "Verify job outputs"
```

---

## 🛠️ Step-by-Step Troubleshooting

### Step 1: Check Secrets

```bash
# List all secrets
gh secret list

# Must have:
DOCKER_USERNAME  ✅
DOCKER_PASSWORD  ✅
GCP_SA_KEY       ✅
GCP_PROJECT_ID   ✅
GKE_CLUSTER_NAME ✅
GKE_ZONE         ✅
```

**If DOCKER_USERNAME is missing:**
```bash
gh secret set DOCKER_USERNAME --body "your-dockerhub-username"
```

### Step 2: Check Build Job Logs

```bash
# View workflow run
gh run view --log

# Look for "Generate image tags" section
gh run view --log | grep -A 10 "Generate image tags"
```

**Should show:**
```
  DOCKER_USER: your-username  ← Must not be empty!
  IMAGE_NAME: ml-model
  PRIMARY_TAG: your-username/ml-model:branch-sha
```

### Step 3: Check Job Outputs

```bash
# Look for verification step
gh run view --log | grep -A 5 "Verify job outputs"
```

**Should show:**
```
🔍 Verifying job outputs...
  primary_tag: username/ml-model:main-abc1234  ← Must not be empty!
✅ Job outputs verified
```

### Step 4: Check Deploy Job Received Output

```bash
# Look for debug step in deploy job
gh run view --log | grep -A 5 "Debug job inputs"
```

**Should show:**
```
  image_tag from build: username/ml-model:main-abc1234  ← Must not be empty!
✅ Received image tag successfully
```

---

## 🔧 Common Fixes

### Fix 1: Add Missing Secret

```bash
# Check if secret exists
gh secret list | grep DOCKER_USERNAME

# If missing, add it
gh secret set DOCKER_USERNAME --body "your-dockerhub-username"

# Verify
gh secret list
```

### Fix 2: Update Secret Value

```bash
# Update existing secret
gh secret set DOCKER_USERNAME --body "correct-username"

# Re-run workflow
gh run rerun <run-id>
```

### Fix 3: Check Workflow Syntax

Open [.github/workflows/ci-cd.yml](.github/workflows/ci-cd.yml) and verify:

```yaml
env:
  DOCKER_REGISTRY: docker.io
  DOCKER_USERNAME: ${{ secrets.DOCKER_USERNAME }}  ← Must reference secret
  IMAGE_NAME: ml-model  ← Must be set
```

### Fix 4: Verify Job Dependencies

Check deploy job has:
```yaml
deploy-standard-gke:
  needs: build-and-push  ← Must depend on build job
  steps:
    - run: echo "${{ needs.build-and-push.outputs.image_tag }}"  ← Access output
```

---

## 📋 Diagnostic Commands

### Check Current Run
```bash
# Get latest run
gh run list --limit 1

# View logs
gh run view --log

# Check specific job
gh run view --log | grep -A 50 "Build and Push"
gh run view --log | grep -A 50 "Deploy to GKE"
```

### Check Secrets
```bash
# List all secrets
gh secret list

# Check specific secret (can't view value, only if it exists)
gh secret list | grep DOCKER_USERNAME
```

### Test Locally
```bash
# Test Docker login
docker login
# Enter your username and token

# If successful, those are your correct credentials
# Use same username for DOCKER_USERNAME secret
```

---

## 🎯 Quick Checklist

Run through this checklist:

- [ ] `DOCKER_USERNAME` secret is set
- [ ] `DOCKER_PASSWORD` secret is set
- [ ] Workflow has `env: IMAGE_NAME: ml-model`
- [ ] Build job completes successfully
- [ ] Build job shows "✅ Job outputs verified"
- [ ] Deploy job shows "✅ Received image tag successfully"
- [ ] Deploy job shows actual image tag (not empty)

---

## 📞 Still Having Issues?

### Collect Debug Info

```bash
# Get full workflow log
gh run view --log > workflow.log

# Check these sections:
grep "Debug: Checking inputs" workflow.log
grep "Generated tags" workflow.log
grep "Verify job outputs" workflow.log
grep "Debug job inputs" workflow.log
```

### Test Build Locally

```bash
# Test tag generation locally
export DOCKER_USER="your-username"
export IMAGE_NAME="ml-model"
export SHORT_SHA=$(git rev-parse --short=7 HEAD)
export BRANCH_NAME=$(git branch --show-current)

PRIMARY_TAG="${DOCKER_USER}/${IMAGE_NAME}:${BRANCH_NAME}-${SHORT_SHA}"
echo "Primary tag: ${PRIMARY_TAG}"

# Should output: your-username/ml-model:main-abc1234
```

If this works locally but not in GitHub Actions:
1. Check your DOCKER_USERNAME secret matches
2. Verify secret is not accidentally empty/whitespace

---

## 💡 Pro Tips

### 1. View Secrets (Safely)

```bash
# Can't view secret values, but can check they exist
gh secret list

# Shows:
# DOCKER_USERNAME  Updated 2024-XX-XX  ← Exists
# DOCKER_PASSWORD  Updated 2024-XX-XX  ← Exists
```

### 2. Test Secret in Workflow

Add temporary debug step:
```yaml
- name: Test secret
  run: |
    if [ -z "${{ secrets.DOCKER_USERNAME }}" ]; then
      echo "Secret is empty!"
    else
      echo "Secret exists (length: ${#DOCKER_USERNAME})"
    fi
```

### 3. Rerun Failed Job

```bash
# Get run ID
gh run list --limit 5

# Rerun specific run
gh run rerun <run-id>

# Or rerun just failed jobs
gh run rerun <run-id> --failed
```

---

## ✅ Expected Workflow

After fixing, you should see:

```
Build Job:
  ✅ DOCKER_USER populated
  ✅ Tags generated
  ✅ Outputs verified
  ✅ Image pushed

Deploy Job:
  ✅ Received image tag
  ✅ Image updated in manifest
  ✅ Replacement verified
  ✅ Deployment successful
```

---

## 🚀 Test the Fixes

```bash
# Commit changes
git add .
git commit -m "Add comprehensive image tag debugging"
git push origin main

# Watch it run
gh run watch

# Check for all ✅ checkmarks in output
```

---

**With all these debug steps, you'll know exactly where the issue is!** 🎯
