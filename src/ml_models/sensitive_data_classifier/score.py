# azure-data-lake-sentinel/src/ml_models/sensitive_data_classifier/score.py

import json
import logging
import os
import joblib

# Initialize logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# The init() method is called once when the container starts.
def init():
    global model
    # AZUREML_MODEL_DIR is an environment variable created by Azure ML SDK
    # that points to the directory where the model is downloaded.
    model_path = os.path.join(os.getenv('AZUREML_MODEL_DIR'), 'sensitive_data_classifier.pkl')
    model = joblib.load(model_path)
    logger.info("Model loaded successfully.")

# The run() method is called for each inference request.
def run(raw_data):
    try:
        data = json.loads(raw_data)
        text = data.get('input_data', {}).get('text')

        if not text:
            return json.dumps({"error": "No 'text' found in input_data."}, ensure_ascii=False)

        prediction = model.predict([text])[0]
        # Get probability if classifier supports it
        prediction_proba = model.predict_proba([text])[0]
        confidence = float(max(prediction_proba))

        result = {
            "classification": str(prediction),
            "confidence": confidence,
            "message": f"Classified as {prediction} with confidence {confidence:.2f}.",
            "detection_details": {
                "input_text_sample": text[:200] + "..." if len(text) > 200 else text,
                "probabilities": {label: prob for label, prob in zip(model.classes_, prediction_proba)}
            }
        }
        logger.info(f"Prediction: {json.dumps(result, ensure_ascii=False)}")
        return json.dumps(result, ensure_ascii=False)
    except Exception as e:
        error_message = f"Error during inference: {str(e)}"
        logger.error(error_message)
        return json.dumps({"error": error_message}, ensure_ascii=False)

