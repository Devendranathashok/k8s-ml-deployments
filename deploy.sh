#!/bin/bash

# Deployment script for ML Model on Kubernetes

set -e

echo "================================================"
echo "ML Model Kubernetes Deployment Script"
echo "================================================"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
IMAGE_NAME="ml-model"
IMAGE_TAG="latest"
REGISTRY=""  # Set your registry here, e.g., "docker.io/username"

# Parse command line arguments
DEPLOYMENT_TYPE="standard"
SKIP_BUILD=false
SKIP_TRAIN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --kserve)
            DEPLOYMENT_TYPE="kserve"
            shift
            ;;
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --skip-train)
            SKIP_TRAIN=true
            shift
            ;;
        --registry)
            REGISTRY="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--kserve] [--skip-build] [--skip-train] [--registry <registry>]"
            exit 1
            ;;
    esac
done

# Set full image name
if [ -n "$REGISTRY" ]; then
    FULL_IMAGE_NAME="${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
else
    FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"
fi

echo -e "${YELLOW}Deployment Configuration:${NC}"
echo "  Type: $DEPLOYMENT_TYPE"
echo "  Image: $FULL_IMAGE_NAME"
echo "  Skip Build: $SKIP_BUILD"
echo "  Skip Train: $SKIP_TRAIN"
echo ""

# Step 1: Train model
if [ "$SKIP_TRAIN" = false ]; then
    echo -e "${YELLOW}Step 1: Training model...${NC}"
    if [ ! -d "venv" ]; then
        echo "Creating virtual environment..."
        python -m venv venv
    fi

    source venv/bin/activate || source venv/Scripts/activate
    pip install -r requirements.txt > /dev/null
    python train_model.py
    deactivate
    echo -e "${GREEN}✓ Model training complete${NC}"
    echo ""
else
    echo -e "${YELLOW}Step 1: Skipping model training${NC}"
    if [ ! -f "model/iris_model.pkl" ]; then
        echo -e "${RED}Error: Model file not found! Run without --skip-train${NC}"
        exit 1
    fi
    echo ""
fi

# Step 2: Build Docker image
if [ "$SKIP_BUILD" = false ]; then
    echo -e "${YELLOW}Step 2: Building Docker image...${NC}"
    docker build -t "$FULL_IMAGE_NAME" .
    echo -e "${GREEN}✓ Docker image built${NC}"
    echo ""

    # Push to registry if specified
    if [ -n "$REGISTRY" ]; then
        echo -e "${YELLOW}Pushing image to registry...${NC}"
        docker push "$FULL_IMAGE_NAME"
        echo -e "${GREEN}✓ Image pushed to registry${NC}"
        echo ""
    fi
else
    echo -e "${YELLOW}Step 2: Skipping Docker build${NC}"
    echo ""
fi

# Step 3: Deploy to Kubernetes
echo -e "${YELLOW}Step 3: Deploying to Kubernetes...${NC}"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl not found. Please install kubectl first.${NC}"
    exit 1
fi

# Check cluster connection
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: Cannot connect to Kubernetes cluster${NC}"
    exit 1
fi

if [ "$DEPLOYMENT_TYPE" = "kserve" ]; then
    echo "Deploying with KServe..."

    # Check if KServe is installed
    if ! kubectl get crd inferenceservices.serving.kserve.io &> /dev/null; then
        echo -e "${RED}Error: KServe CRD not found. Please install KServe first.${NC}"
        echo "Installation: curl -s 'https://raw.githubusercontent.com/kserve/kserve/release-0.11/hack/quick_install.sh' | bash"
        exit 1
    fi

    # Update image in KServe manifest
    sed -i.bak "s|image:.*|image: $FULL_IMAGE_NAME|g" k8s/kserve-inferenceservice.yaml

    kubectl apply -f k8s/kserve-inferenceservice.yaml

    echo -e "${GREEN}✓ KServe InferenceService deployed${NC}"
    echo ""
    echo "Check status with:"
    echo "  kubectl get inferenceservices"
    echo "  kubectl get pods"

else
    echo "Deploying with standard Kubernetes..."

    # Update image in deployment manifest
    sed -i.bak "s|image:.*|image: $FULL_IMAGE_NAME|g" k8s/deployment.yaml

    kubectl apply -f k8s/deployment.yaml

    echo -e "${GREEN}✓ Deployment created${NC}"
    echo ""
    echo "Check status with:"
    echo "  kubectl get deployments"
    echo "  kubectl get pods"
    echo "  kubectl get services"
fi

echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo "Next steps:"
echo "1. Wait for pods to be ready: kubectl get pods -w"
echo "2. Access the service:"
if [ "$DEPLOYMENT_TYPE" = "kserve" ]; then
    echo "   kubectl port-forward service/iris-model-predictor-default 8080:80"
else
    echo "   kubectl port-forward service/ml-model-service 8080:80"
fi
echo "3. Test with client: python client.py"
