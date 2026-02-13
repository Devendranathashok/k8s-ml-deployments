"""
Flask API to serve the ML model
"""

from flask import Flask, request, jsonify
from flask_cors import CORS
import joblib
import numpy as np
import os
from datetime import datetime

app = Flask(__name__)
CORS(app)

# Global variables for model and metadata
model = None
metadata = None

def load_model():
    """Load the trained model and metadata"""
    global model, metadata

    model_path = 'model/iris_model.pkl'
    metadata_path = 'model/metadata.pkl'

    if not os.path.exists(model_path):
        raise FileNotFoundError(f"Model file not found at {model_path}")

    if not os.path.exists(metadata_path):
        raise FileNotFoundError(f"Metadata file not found at {metadata_path}")

    model = joblib.load(model_path)
    metadata = joblib.load(metadata_path)

    print("Model and metadata loaded successfully!")
    print(f"Feature names: {metadata['feature_names']}")
    print(f"Target names: {metadata['target_names']}")

@app.route('/')
def home():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'message': 'ML Model API is running',
        'timestamp': datetime.utcnow().isoformat(),
        'model_loaded': model is not None
    })

@app.route('/health')
def health():
    """Kubernetes health check endpoint"""
    if model is None:
        return jsonify({
            'status': 'unhealthy',
            'reason': 'model not loaded'
        }), 503

    return jsonify({
        'status': 'healthy'
    })

@app.route('/model/info')
def model_info():
    """Get information about the model"""
    if model is None:
        return jsonify({'error': 'Model not loaded'}), 503

    return jsonify({
        'feature_names': metadata['feature_names'],
        'target_names': list(metadata['target_names']),
        'num_features': len(metadata['feature_names']),
        'num_classes': len(metadata['target_names']),
        'model_type': type(model).__name__
    })

@app.route('/predict', methods=['POST'])
def predict():
    """Make predictions"""
    if model is None:
        return jsonify({'error': 'Model not loaded'}), 503

    try:
        # Get input data
        data = request.get_json()

        if 'features' not in data:
            return jsonify({
                'error': 'Missing "features" in request body',
                'example': {
                    'features': [5.1, 3.5, 1.4, 0.2]
                }
            }), 400

        features = data['features']

        # Validate input
        if not isinstance(features, list):
            return jsonify({'error': 'features must be a list'}), 400

        if len(features) != len(metadata['feature_names']):
            return jsonify({
                'error': f'Expected {len(metadata["feature_names"])} features, got {len(features)}',
                'expected_features': metadata['feature_names']
            }), 400

        # Make prediction
        features_array = np.array([features])
        prediction = model.predict(features_array)[0]
        probabilities = model.predict_proba(features_array)[0]

        # Prepare response
        result = {
            'prediction': int(prediction),
            'predicted_class': metadata['target_names'][prediction],
            'probabilities': {
                metadata['target_names'][i]: float(prob)
                for i, prob in enumerate(probabilities)
            },
            'confidence': float(max(probabilities)),
            'timestamp': datetime.utcnow().isoformat()
        }

        return jsonify(result)

    except Exception as e:
        return jsonify({
            'error': str(e),
            'type': type(e).__name__
        }), 500

@app.route('/predict/batch', methods=['POST'])
def predict_batch():
    """Make batch predictions"""
    if model is None:
        return jsonify({'error': 'Model not loaded'}), 503

    try:
        data = request.get_json()

        if 'samples' not in data:
            return jsonify({
                'error': 'Missing "samples" in request body',
                'example': {
                    'samples': [
                        [5.1, 3.5, 1.4, 0.2],
                        [6.2, 2.9, 4.3, 1.3]
                    ]
                }
            }), 400

        samples = data['samples']

        if not isinstance(samples, list):
            return jsonify({'error': 'samples must be a list'}), 400

        # Validate and predict
        features_array = np.array(samples)

        if features_array.shape[1] != len(metadata['feature_names']):
            return jsonify({
                'error': f'Expected {len(metadata["feature_names"])} features per sample',
                'expected_features': metadata['feature_names']
            }), 400

        predictions = model.predict(features_array)
        probabilities = model.predict_proba(features_array)

        # Prepare response
        results = []
        for i, (pred, probs) in enumerate(zip(predictions, probabilities)):
            results.append({
                'sample_index': i,
                'prediction': int(pred),
                'predicted_class': metadata['target_names'][pred],
                'probabilities': {
                    metadata['target_names'][j]: float(prob)
                    for j, prob in enumerate(probs)
                },
                'confidence': float(max(probs))
            })

        return jsonify({
            'predictions': results,
            'total_samples': len(results),
            'timestamp': datetime.utcnow().isoformat()
        })

    except Exception as e:
        return jsonify({
            'error': str(e),
            'type': type(e).__name__
        }), 500

if __name__ == '__main__':
    # Load model on startup
    load_model()

    # Run the app
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=False)
