# Quick Start Guide

Get your ML model deployed on Kubernetes in minutes!

## Prerequisites

- Python 3.11+
- Docker Desktop (with Kubernetes enabled)
- kubectl

## Quick Deploy (5 Minutes)

### Option 1: Automated Deployment (Recommended)

**Windows (PowerShell):**
```powershell
# Standard Kubernetes
.\deploy.ps1

# With KServe
.\deploy.ps1 -KServe
```

**Linux/Mac:**
```bash
# Make script executable
chmod +x deploy.sh

# Standard Kubernetes
./deploy.sh

# With KServe
./deploy.sh --kserve
```

### Option 2: Manual Deployment

```bash
# 1. Train the model
pip install -r requirements.txt
python train_model.py

# 2. Build Docker image
docker build -t ml-model:latest .

# 3. Deploy to Kubernetes
kubectl apply -f k8s/deployment.yaml

# 4. Wait for pods
kubectl get pods -w
```

## Test Your Deployment

```bash
# Forward port to local machine
kubectl port-forward service/ml-model-service 8080:80

# In another terminal, test the API
curl http://localhost:8080/health

# Or use the Python client
pip install -r client_requirements.txt
python client.py
```

## What's Next?

- Read the full [README.md](README.md) for detailed documentation
- Configure [ingress](k8s/ingress.yaml) for external access
- Enable [autoscaling](k8s/hpa.yaml) for production
- Try [KServe](k8s/kserve-inferenceservice.yaml) for advanced features

## Troubleshooting

**Pods not starting?**
```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

**Can't access service?**
```bash
kubectl get service ml-model-service
kubectl get pods
```

**Docker image issues?**
```bash
# For minikube/kind, load image directly
minikube image load ml-model:latest
# or
kind load docker-image ml-model:latest
```

## Clean Up

```bash
# Remove deployment
kubectl delete -f k8s/deployment.yaml

# Stop port-forward
# Press Ctrl+C in the terminal running port-forward
```

## Architecture

```
┌─────────────┐
│   Client    │
│  (Python)   │
└──────┬──────┘
       │
       │ HTTP
       ▼
┌─────────────────┐
│   Kubernetes    │
│   Load Balancer │
└────────┬────────┘
         │
    ┌────┴────┐
    │         │
    ▼         ▼
┌────────┐ ┌────────┐
│  Pod 1 │ │  Pod 2 │  ... (Auto-scaled)
│ Flask  │ │ Flask  │
│ + ML   │ │ + ML   │
│ Model  │ │ Model  │
└────────┘ └────────┘
```

## Example Predictions

The model predicts Iris flower species based on measurements:

**Input:** Sepal length, Sepal width, Petal length, Petal width (in cm)

**Example 1 - Setosa:**
```json
{
  "features": [5.1, 3.5, 1.4, 0.2]
}
```

**Example 2 - Versicolor:**
```json
{
  "features": [6.2, 2.9, 4.3, 1.3]
}
```

**Example 3 - Virginica:**
```json
{
  "features": [7.3, 2.9, 6.3, 1.8]
}
```

## Support

For issues and questions, check the full [README.md](README.md) or file an issue on GitHub.
