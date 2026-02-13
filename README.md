# ML Model Deployment on Kubernetes

A complete example of training, deploying, and serving a machine learning model on Kubernetes with options for both standard deployment and KServe.

## Project Structure

```
ml-k8s-deployment/
├── train_model.py              # Model training script
├── app.py                      # Flask API service
├── client.py                   # Python client for testing
├── requirements.txt            # Python dependencies for service
├── client_requirements.txt     # Python dependencies for client
├── Dockerfile                  # Docker image definition
├── .dockerignore              # Docker ignore file
├── k8s/                       # Kubernetes manifests
│   ├── deployment.yaml        # Standard K8s deployment
│   ├── ingress.yaml          # Ingress configuration
│   ├── hpa.yaml              # Horizontal Pod Autoscaler
│   └── kserve-inferenceservice.yaml  # KServe configuration
└── README.md                  # This file
```

## Prerequisites

- Python 3.11+
- Docker
- Kubernetes cluster (minikube, kind, or cloud provider)
- kubectl configured
- (Optional) KServe for advanced model serving

## Step 1: Train the Model

Install dependencies and train the model:

```bash
# Install training dependencies
pip install -r requirements.txt

# Train and save the model
python train_model.py
```

This will:
- Load the Iris dataset
- Train a Random Forest classifier
- Save the model to `model/iris_model.pkl`
- Save metadata to `model/metadata.pkl`

## Step 2: Test Locally (Optional)

Test the Flask API locally before deploying:

```bash
# Run the Flask app
python app.py
```

In another terminal, test with the client:

```bash
# Install client dependencies
pip install -r client_requirements.txt

# Run the demo client
python client.py

# Or run interactive mode
python client.py --interactive
```

## Step 3: Build Docker Image

Build and tag the Docker image:

```bash
# Build the image
docker build -t ml-model:latest .

# Test the Docker image locally
docker run -p 5000:5000 ml-model:latest

# (Optional) Test with curl
curl http://localhost:5000/health
```

If pushing to a registry:

```bash
# Tag for your registry
docker tag ml-model:latest <your-registry>/ml-model:latest

# Push to registry
docker push <your-registry>/ml-model:latest
```

## Step 4: Deploy to Kubernetes

### Option A: Standard Kubernetes Deployment

Deploy using standard Kubernetes resources:

```bash
# Deploy the application
kubectl apply -f k8s/deployment.yaml

# Check deployment status
kubectl get deployments
kubectl get pods
kubectl get services

# Check logs
kubectl logs -l app=ml-model

# Get the service endpoint
kubectl get service ml-model-service
```

#### Access the Service

**Using LoadBalancer:**
```bash
# Get external IP (may take a few minutes)
kubectl get service ml-model-service

# Once you have the EXTERNAL-IP, test it
curl http://<EXTERNAL-IP>/health
```

**Using Port Forward (for testing):**
```bash
# Forward local port to service
kubectl port-forward service/ml-model-service 8080:80

# Test in another terminal
curl http://localhost:8080/health
python client.py  # Make sure SERVICE_URL is http://localhost:8080
```

**Using Ingress:**
```bash
# Install nginx ingress controller (if not already installed)
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml

# Apply ingress configuration
kubectl apply -f k8s/ingress.yaml

# Add to /etc/hosts (or C:\Windows\System32\drivers\etc\hosts on Windows)
# Get ingress IP: kubectl get ingress ml-model-ingress
<INGRESS-IP> ml-model.local

# Test
curl http://ml-model.local/health
```

#### Enable Autoscaling

```bash
# Apply HPA configuration
kubectl apply -f k8s/hpa.yaml

# Check HPA status
kubectl get hpa ml-model-hpa

# Watch autoscaling in action
kubectl get hpa -w
```

### Option B: KServe Deployment (Advanced)

KServe provides advanced features like:
- Automatic scaling to zero
- Canary deployments
- Model versioning
- Request/response logging
- Advanced monitoring

#### Install KServe

```bash
# Install KServe (quick start)
curl -s "https://raw.githubusercontent.com/kserve/kserve/release-0.11/hack/quick_install.sh" | bash

# Verify installation
kubectl get pods -n kserve

# Check if InferenceService CRD is installed
kubectl get crd inferenceservices.serving.kserve.io
```

#### Deploy with KServe

```bash
# Create a namespace for your models (optional)
kubectl create namespace ml-models

# Deploy the InferenceService
kubectl apply -f k8s/kserve-inferenceservice.yaml -n ml-models

# Check status
kubectl get inferenceservices -n ml-models
kubectl get pods -n ml-models

# Get the service URL
kubectl get inferenceservice iris-model -n ml-models

# Describe for more details
kubectl describe inferenceservice iris-model -n ml-models
```

#### Access KServe Service

```bash
# Get the ingress host and IP
export INGRESS_HOST=$(kubectl get inferenceservice iris-model -n ml-models -o jsonpath='{.status.url}' | cut -d "/" -f 3)
export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')

# Test the service
curl -v -H "Host: ${INGRESS_HOST}" http://${INGRESS_PORT}/health

# Or use port-forward
kubectl port-forward -n ml-models service/iris-model-predictor-default 8080:80

# Test
curl http://localhost:8080/health
```

## Step 5: Use the Deployed Model

Update the `SERVICE_URL` in [client.py](client.py) based on your deployment method:

```python
# For LoadBalancer
SERVICE_URL = "http://<EXTERNAL-IP>"

# For port-forward
SERVICE_URL = "http://localhost:8080"

# For Ingress
SERVICE_URL = "http://ml-model.local"

# For KServe port-forward
SERVICE_URL = "http://localhost:8080"
```

Run the client:

```bash
# Demo mode
python client.py

# Interactive mode
python client.py --interactive
```

## API Endpoints

### Health Check
```bash
GET /health
GET /

Response: {"status": "healthy"}
```

### Model Info
```bash
GET /model/info

Response:
{
  "feature_names": [...],
  "target_names": [...],
  "num_features": 4,
  "num_classes": 3,
  "model_type": "RandomForestClassifier"
}
```

### Single Prediction
```bash
POST /predict
Content-Type: application/json

Body:
{
  "features": [5.1, 3.5, 1.4, 0.2]
}

Response:
{
  "prediction": 0,
  "predicted_class": "setosa",
  "probabilities": {
    "setosa": 0.98,
    "versicolor": 0.01,
    "virginica": 0.01
  },
  "confidence": 0.98
}
```

### Batch Prediction
```bash
POST /predict/batch
Content-Type: application/json

Body:
{
  "samples": [
    [5.1, 3.5, 1.4, 0.2],
    [6.2, 2.9, 4.3, 1.3]
  ]
}

Response:
{
  "predictions": [...],
  "total_samples": 2
}
```

## Monitoring and Debugging

### Check Logs
```bash
# All pods
kubectl logs -l app=ml-model

# Specific pod
kubectl logs <pod-name>

# Follow logs
kubectl logs -f <pod-name>

# Previous crashed container
kubectl logs <pod-name> --previous
```

### Exec into Pod
```bash
# Get shell access
kubectl exec -it <pod-name> -- /bin/bash

# Run commands
kubectl exec <pod-name> -- python -c "import joblib; print(joblib.__version__)"
```

### Resource Usage
```bash
# Check resource usage
kubectl top pods
kubectl top nodes

# Describe pod for events
kubectl describe pod <pod-name>
```

## Scaling

### Manual Scaling
```bash
# Scale to 5 replicas
kubectl scale deployment ml-model-deployment --replicas=5

# Check status
kubectl get deployments
```

### Auto Scaling (HPA)
```bash
# HPA is configured to scale between 2-10 pods based on CPU/memory
kubectl get hpa

# Generate load to test autoscaling
kubectl run -it --rm load-generator --image=busybox /bin/sh
# Inside the pod:
while true; do wget -q -O- http://ml-model-service/predict; done
```

## Cleanup

### Standard Kubernetes
```bash
# Delete all resources
kubectl delete -f k8s/deployment.yaml
kubectl delete -f k8s/ingress.yaml
kubectl delete -f k8s/hpa.yaml
```

### KServe
```bash
# Delete InferenceService
kubectl delete -f k8s/kserve-inferenceservice.yaml -n ml-models

# Delete namespace (if created)
kubectl delete namespace ml-models
```

## Production Considerations

1. **Security:**
   - Use secrets for sensitive data
   - Implement authentication/authorization
   - Enable TLS/HTTPS
   - Use network policies

2. **Monitoring:**
   - Set up Prometheus metrics
   - Configure Grafana dashboards
   - Enable logging (ELK/EFK stack)
   - Set up alerts

3. **High Availability:**
   - Use multiple replicas
   - Configure pod disruption budgets
   - Use node affinity/anti-affinity
   - Set up health checks

4. **Model Management:**
   - Version your models
   - Use persistent volumes for model storage
   - Implement A/B testing
   - Set up canary deployments

5. **Performance:**
   - Use GPU nodes for large models
   - Implement request batching
   - Configure resource limits appropriately
   - Use caching where applicable

## KServe vs Standard Kubernetes

### Use Standard Kubernetes When:
- Simple model serving requirements
- Full control over deployment
- Custom API endpoints needed
- Existing infrastructure to maintain

### Use KServe When:
- Need advanced ML serving features
- Want automatic scaling to zero
- Need model versioning and canary deployments
- Want built-in monitoring and explainability
- Working with multiple ML frameworks
- Need multi-model serving

## Troubleshooting

### Pods not starting
```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

### Service not accessible
```bash
kubectl get endpoints ml-model-service
kubectl get service ml-model-service
```

### Image pull errors
```bash
# Check image pull secrets
kubectl get secrets

# Verify image name and tag
kubectl describe pod <pod-name>
```

### Model not loading
```bash
# Check if model files exist in the image
kubectl exec <pod-name> -- ls -la /app/model/
```

## License

MIT License - feel free to use this for your projects!

## Contributing

Contributions welcome! Please submit issues and pull requests.
