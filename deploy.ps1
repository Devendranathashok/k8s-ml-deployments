# PowerShell deployment script for ML Model on Kubernetes

param(
    [switch]$KServe,
    [switch]$SkipBuild,
    [switch]$SkipTrain,
    [string]$Registry = ""
)

$ErrorActionPreference = "Stop"

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "ML Model Kubernetes Deployment Script" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

# Configuration
$IMAGE_NAME = "ml-model"
$IMAGE_TAG = "latest"

# Determine deployment type
$DEPLOYMENT_TYPE = if ($KServe) { "kserve" } else { "standard" }

# Set full image name
$FULL_IMAGE_NAME = if ($Registry) {
    "${Registry}/${IMAGE_NAME}:${IMAGE_TAG}"
} else {
    "${IMAGE_NAME}:${IMAGE_TAG}"
}

Write-Host ""
Write-Host "Deployment Configuration:" -ForegroundColor Yellow
Write-Host "  Type: $DEPLOYMENT_TYPE"
Write-Host "  Image: $FULL_IMAGE_NAME"
Write-Host "  Skip Build: $SkipBuild"
Write-Host "  Skip Train: $SkipTrain"
Write-Host ""

# Step 1: Train model
if (-not $SkipTrain) {
    Write-Host "Step 1: Training model..." -ForegroundColor Yellow

    if (-not (Test-Path "venv")) {
        Write-Host "Creating virtual environment..."
        python -m venv venv
    }

    & .\venv\Scripts\Activate.ps1
    pip install -r requirements.txt | Out-Null
    python train_model.py
    deactivate

    Write-Host "✓ Model training complete" -ForegroundColor Green
    Write-Host ""
} else {
    Write-Host "Step 1: Skipping model training" -ForegroundColor Yellow
    if (-not (Test-Path "model\iris_model.pkl")) {
        Write-Host "Error: Model file not found! Run without -SkipTrain" -ForegroundColor Red
        exit 1
    }
    Write-Host ""
}

# Step 2: Build Docker image
if (-not $SkipBuild) {
    Write-Host "Step 2: Building Docker image..." -ForegroundColor Yellow
    docker build -t $FULL_IMAGE_NAME .
    Write-Host "✓ Docker image built" -ForegroundColor Green
    Write-Host ""

    # Push to registry if specified
    if ($Registry) {
        Write-Host "Pushing image to registry..." -ForegroundColor Yellow
        docker push $FULL_IMAGE_NAME
        Write-Host "✓ Image pushed to registry" -ForegroundColor Green
        Write-Host ""
    }
} else {
    Write-Host "Step 2: Skipping Docker build" -ForegroundColor Yellow
    Write-Host ""
}

# Step 3: Deploy to Kubernetes
Write-Host "Step 3: Deploying to Kubernetes..." -ForegroundColor Yellow

# Check if kubectl is available
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Host "Error: kubectl not found. Please install kubectl first." -ForegroundColor Red
    exit 1
}

# Check cluster connection
try {
    kubectl cluster-info | Out-Null
} catch {
    Write-Host "Error: Cannot connect to Kubernetes cluster" -ForegroundColor Red
    exit 1
}

if ($DEPLOYMENT_TYPE -eq "kserve") {
    Write-Host "Deploying with KServe..."

    # Check if KServe is installed
    try {
        kubectl get crd inferenceservices.serving.kserve.io | Out-Null
    } catch {
        Write-Host "Error: KServe CRD not found. Please install KServe first." -ForegroundColor Red
        Write-Host "Installation: curl -s 'https://raw.githubusercontent.com/kserve/kserve/release-0.11/hack/quick_install.sh' | bash"
        exit 1
    }

    # Update image in KServe manifest
    $content = Get-Content k8s\kserve-inferenceservice.yaml
    $content = $content -replace 'image:.*', "image: $FULL_IMAGE_NAME"
    $content | Set-Content k8s\kserve-inferenceservice.yaml

    kubectl apply -f k8s\kserve-inferenceservice.yaml

    Write-Host "✓ KServe InferenceService deployed" -ForegroundColor Green
    Write-Host ""
    Write-Host "Check status with:"
    Write-Host "  kubectl get inferenceservices"
    Write-Host "  kubectl get pods"

} else {
    Write-Host "Deploying with standard Kubernetes..."

    # Update image in deployment manifest
    $content = Get-Content k8s\deployment.yaml
    $content = $content -replace 'image:.*', "image: $FULL_IMAGE_NAME"
    $content | Set-Content k8s\deployment.yaml

    kubectl apply -f k8s\deployment.yaml

    Write-Host "✓ Deployment created" -ForegroundColor Green
    Write-Host ""
    Write-Host "Check status with:"
    Write-Host "  kubectl get deployments"
    Write-Host "  kubectl get pods"
    Write-Host "  kubectl get services"
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Green
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:"
Write-Host "1. Wait for pods to be ready: kubectl get pods -w"
Write-Host "2. Access the service:"
if ($DEPLOYMENT_TYPE -eq "kserve") {
    Write-Host "   kubectl port-forward service/iris-model-predictor-default 8080:80"
} else {
    Write-Host "   kubectl port-forward service/ml-model-service 8080:80"
}
Write-Host "3. Test with client: python client.py"
