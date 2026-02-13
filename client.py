"""
Python client to interact with the deployed ML model
"""

import requests
import json
import sys
from typing import List, Dict, Any

class MLModelClient:
    """Client for interacting with the ML model API"""

    def __init__(self, base_url: str):
        """
        Initialize the client

        Args:
            base_url: Base URL of the model service (e.g., http://localhost:5000)
        """
        self.base_url = base_url.rstrip('/')
        self.session = requests.Session()

    def health_check(self) -> Dict[str, Any]:
        """Check if the service is healthy"""
        try:
            response = self.session.get(f"{self.base_url}/health", timeout=5)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            return {"status": "error", "message": str(e)}

    def get_model_info(self) -> Dict[str, Any]:
        """Get information about the model"""
        try:
            response = self.session.get(f"{self.base_url}/model/info", timeout=5)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            print(f"Error getting model info: {e}")
            sys.exit(1)

    def predict(self, features: List[float]) -> Dict[str, Any]:
        """
        Make a single prediction

        Args:
            features: List of feature values

        Returns:
            Dictionary with prediction results
        """
        try:
            payload = {"features": features}
            response = self.session.post(
                f"{self.base_url}/predict",
                json=payload,
                timeout=10
            )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            print(f"Error making prediction: {e}")
            if hasattr(e.response, 'text'):
                print(f"Response: {e.response.text}")
            sys.exit(1)

    def predict_batch(self, samples: List[List[float]]) -> Dict[str, Any]:
        """
        Make batch predictions

        Args:
            samples: List of sample feature lists

        Returns:
            Dictionary with batch prediction results
        """
        try:
            payload = {"samples": samples}
            response = self.session.post(
                f"{self.base_url}/predict/batch",
                json=payload,
                timeout=30
            )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            print(f"Error making batch prediction: {e}")
            if hasattr(e.response, 'text'):
                print(f"Response: {e.response.text}")
            sys.exit(1)


def print_json(data: Dict[str, Any]):
    """Pretty print JSON data"""
    print(json.dumps(data, indent=2))


def main():
    """Main function demonstrating client usage"""
    # Configure the service URL
    # For local testing: http://localhost:5000
    # For Kubernetes LoadBalancer: http://<EXTERNAL-IP>
    # For Kubernetes Ingress: http://ml-model.local
    SERVICE_URL = "http://localhost:5000"

    print("="*60)
    print("ML Model Client Demo")
    print("="*60)

    # Initialize client
    client = MLModelClient(SERVICE_URL)

    # 1. Health check
    print("\n1. Checking service health...")
    health = client.health_check()
    print_json(health)

    if health.get('status') != 'healthy':
        print("\nService is not healthy. Please check the deployment.")
        sys.exit(1)

    # 2. Get model info
    print("\n2. Getting model information...")
    model_info = client.get_model_info()
    print_json(model_info)

    # 3. Single prediction
    print("\n3. Making single prediction...")
    print("\nInput features (Iris flower measurements):")

    # Example: Setosa
    features = [5.1, 3.5, 1.4, 0.2]
    print(f"  Sepal length: {features[0]} cm")
    print(f"  Sepal width:  {features[1]} cm")
    print(f"  Petal length: {features[2]} cm")
    print(f"  Petal width:  {features[3]} cm")

    result = client.predict(features)
    print("\nPrediction result:")
    print_json(result)

    # 4. Batch predictions
    print("\n4. Making batch predictions...")

    samples = [
        [5.1, 3.5, 1.4, 0.2],  # Setosa
        [6.2, 2.9, 4.3, 1.3],  # Versicolor
        [7.3, 2.9, 6.3, 1.8],  # Virginica
    ]

    print(f"\nProcessing {len(samples)} samples...")
    batch_result = client.predict_batch(samples)

    print("\nBatch prediction results:")
    for pred in batch_result['predictions']:
        print(f"\nSample {pred['sample_index']}:")
        print(f"  Predicted class: {pred['predicted_class']}")
        print(f"  Confidence: {pred['confidence']:.4f}")
        print(f"  Probabilities:")
        for class_name, prob in pred['probabilities'].items():
            print(f"    {class_name}: {prob:.4f}")

    print("\n" + "="*60)
    print("Demo completed successfully!")
    print("="*60)


def interactive_mode():
    """Interactive mode for manual predictions"""
    SERVICE_URL = input("Enter service URL (default: http://localhost:5000): ").strip()
    if not SERVICE_URL:
        SERVICE_URL = "http://localhost:5000"

    client = MLModelClient(SERVICE_URL)

    # Check health
    health = client.health_check()
    if health.get('status') != 'healthy':
        print("Service is not healthy!")
        print_json(health)
        sys.exit(1)

    print("\nService is healthy!")

    # Get model info
    model_info = client.get_model_info()
    print("\nModel Information:")
    print_json(model_info)

    print("\n" + "="*60)
    print("Interactive Prediction Mode")
    print("="*60)

    while True:
        print("\nEnter feature values (or 'quit' to exit):")

        try:
            sepal_length = input("  Sepal length (cm): ").strip()
            if sepal_length.lower() == 'quit':
                break

            sepal_width = input("  Sepal width (cm): ").strip()
            petal_length = input("  Petal length (cm): ").strip()
            petal_width = input("  Petal width (cm): ").strip()

            features = [
                float(sepal_length),
                float(sepal_width),
                float(petal_length),
                float(petal_width)
            ]

            result = client.predict(features)
            print("\nPrediction:")
            print(f"  Class: {result['predicted_class']}")
            print(f"  Confidence: {result['confidence']:.4f}")
            print("\n  Probabilities:")
            for class_name, prob in result['probabilities'].items():
                print(f"    {class_name}: {prob:.4f}")

        except ValueError as e:
            print(f"\nInvalid input: {e}")
        except KeyboardInterrupt:
            print("\n\nExiting...")
            break

    print("\nGoodbye!")


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--interactive":
        interactive_mode()
    else:
        main()
