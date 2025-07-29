# azure-data-lake-sentinel/src/ml_models/sensitive_data_classifier/train.py

import argparse
import os
import logging
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.pipeline import Pipeline
from sklearn.metrics import classification_report
import joblib

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Train a sensitive data classifier.")
    parser.add_argument("--data_path", type=str, default="data", help="Path to the training data.")
    parser.add_argument("--model_output_path", type=str, default="model", help="Path to save the trained model.")
    args = parser.parse_args()

    logger.info(f"Loading data from {args.data_path}")

    # --- 1. Load Data ---
    # Assuming input data is a CSV with 'text' and 'label' columns
    # In Azure ML, this 'data_path' refers to a mounted dataset.
    data_file = os.path.join(args.data_path, "training_data.csv")
    if not os.path.exists(data_file):
        raise FileNotFoundError(f"Training data file not found: {data_file}")

    df = pd.read_csv(data_file)
    logger.info(f"Loaded {len(df)} samples.")
    logger.info(f"Labels distribution:\n{df['label'].value_counts()}")

    # --- 2. Data Preprocessing & Feature Engineering ---
    # Simplified text preprocessing and TF-IDF vectorization
    X = df["text"].fillna("") # Handle potential NaN
    y = df["label"]

    # --- 3. Model Training ---
    logger.info("Splitting data and training model pipeline...")
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42, stratify=y)

    # Create a simple NLP pipeline: TF-IDF Vectorizer + Logistic Regression Classifier
    pipeline = Pipeline([
        ('tfidf', TfidfVectorizer(max_features=5000, stop_words='english')),
        ('classifier', LogisticRegression(random_state=42, max_iter=1000))
    ])

    pipeline.fit(X_train, y_train)
    logger.info("Model training complete.")

    # --- 4. Evaluation ---
    y_pred = pipeline.predict(X_test)
    report = classification_report(y_test, y_pred, output_dict=True)
    logger.info(f"Classification Report:\n{json.dumps(report, indent=2)}")

    # --- 5. Save Model ---
    # Azure ML expects model artifacts to be saved to the 'outputs' folder,
    # which is then automatically uploaded to AML Workspace's default datastore.
    model_save_path = os.path.join(args.model_output_path, "sensitive_data_classifier.pkl")
    joblib.dump(pipeline, model_save_path)
    logger.info(f"Model saved to {model_save_path}")

    # Save metrics for AML tracking
    import json
    with open(os.path.join(args.model_output_path, 'metrics.json'), 'w') as f:
        json.dump(report, f)
