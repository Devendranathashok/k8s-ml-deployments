"""
Train a simple ML model for classification
This example creates a model to predict iris flower species
"""

import numpy as np
import pandas as pd
from sklearn.datasets import load_iris
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, classification_report
import joblib
import os

def create_data():
    """Load and prepare the iris dataset"""
    print("Loading iris dataset...")
    iris = load_iris()

    # Create DataFrame for better visualization
    df = pd.DataFrame(
        data=iris.data,
        columns=iris.feature_names
    )
    df['target'] = iris.target
    df['species'] = df['target'].map({
        0: iris.target_names[0],
        1: iris.target_names[1],
        2: iris.target_names[2]
    })

    print(f"\nDataset shape: {df.shape}")
    print(f"\nFirst few rows:")
    print(df.head())
    print(f"\nClass distribution:")
    print(df['species'].value_counts())

    return iris.data, iris.target, iris.feature_names, iris.target_names

def train_model(X, y):
    """Train a Random Forest classifier"""
    print("\n" + "="*50)
    print("Training model...")
    print("="*50)

    # Split data
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42
    )

    # Create and train model
    model = RandomForestClassifier(
        n_estimators=100,
        max_depth=5,
        random_state=42
    )

    model.fit(X_train, y_train)

    # Evaluate
    y_pred = model.predict(X_test)
    accuracy = accuracy_score(y_test, y_pred)

    print(f"\nModel trained successfully!")
    print(f"Training samples: {len(X_train)}")
    print(f"Test samples: {len(X_test)}")
    print(f"Accuracy: {accuracy:.4f}")
    print("\nClassification Report:")
    print(classification_report(y_test, y_pred))

    return model

def save_model(model, feature_names, target_names, output_dir='model'):
    """Save the trained model and metadata"""
    os.makedirs(output_dir, exist_ok=True)

    model_path = os.path.join(output_dir, 'iris_model.pkl')
    metadata_path = os.path.join(output_dir, 'metadata.pkl')

    # Save model
    joblib.dump(model, model_path)

    # Save metadata
    metadata = {
        'feature_names': feature_names,
        'target_names': target_names
    }
    joblib.dump(metadata, metadata_path)

    print(f"\n" + "="*50)
    print(f"Model saved to: {model_path}")
    print(f"Metadata saved to: {metadata_path}")
    print("="*50)

def main():
    """Main training pipeline"""
    print("Starting ML Model Training Pipeline")
    print("="*50)

    # Create data
    X, y, feature_names, target_names = create_data()

    # Train model
    model = train_model(X, y)

    # Save model
    save_model(model, feature_names, target_names)

    print("\nTraining complete! Model is ready for deployment.")

if __name__ == "__main__":
    main()
