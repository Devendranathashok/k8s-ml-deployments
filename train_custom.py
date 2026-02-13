"""
Train model with custom CSV data
Usage: python train_custom.py --data mydata.csv
"""

import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, classification_report
from sklearn.preprocessing import LabelEncoder
import joblib
import os
import argparse

def load_custom_data(csv_path, target_column, feature_columns=None):
    """Load data from CSV file"""
    print(f"Loading data from: {csv_path}")
    df = pd.read_csv(csv_path)

    print(f"Dataset shape: {df.shape}")
    print(f"\nFirst few rows:")
    print(df.head())

    # Extract features and target
    if feature_columns:
        X = df[feature_columns].values
    else:
        # Use all columns except target
        X = df.drop(columns=[target_column]).values
        feature_columns = df.drop(columns=[target_column]).columns.tolist()

    # Encode string labels to integers
    label_encoder = LabelEncoder()
    y = label_encoder.fit_transform(df[target_column].values)

    # Get target names in the order of encoded labels
    target_names = label_encoder.classes_.tolist()

    print(f"\nFeatures: {feature_columns}")
    print(f"Target classes: {target_names}")
    print(f"Label encoding: {dict(enumerate(target_names))}")
    print(f"Class distribution:")
    print(df[target_column].value_counts())

    return X, y, feature_columns, target_names

def train_model(X, y):
    """Train a Random Forest classifier"""
    print("\n" + "="*50)
    print("Training model...")
    print("="*50)

    # Split data
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )

    # Create and train model
    model = RandomForestClassifier(
        n_estimators=100,
        max_depth=10,
        random_state=42,
        n_jobs=-1
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

    # Feature importance
    importances = model.feature_importances_
    print("\nTop 5 Important Features:")
    for i in np.argsort(importances)[-5:][::-1]:
        print(f"  {i}: {importances[i]:.4f}")

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
    parser = argparse.ArgumentParser(description='Train model with custom CSV data')
    parser.add_argument('--data', type=str, required=True, help='Path to CSV file')
    parser.add_argument('--target', type=str, required=True, help='Target column name')
    parser.add_argument('--features', type=str, nargs='*', help='Feature column names (optional)')

    args = parser.parse_args()

    print("Starting Custom ML Model Training Pipeline")
    print("="*50)

    # Load data
    X, y, feature_names, target_names = load_custom_data(
        args.data,
        args.target,
        args.features
    )

    # Train model
    model = train_model(X, y)

    # Save model
    save_model(model, feature_names, target_names)

    print("\nTraining complete! Model is ready for deployment.")
    print("\nNext steps:")
    print("1. docker build -t ml-model:latest .")
    print("2. docker push ml-model:latest")
    print("3. Deploy to Kubernetes")

if __name__ == "__main__":
    main()
