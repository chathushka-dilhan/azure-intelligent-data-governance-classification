# azure-data-lake-sentinel/src/data_processing_scripts/classification_pipeline/batch_classifier.py

import os
import argparse
import logging
import pandas as pd
from azure.identity import DefaultAzureCredential
from azure.ai.ml import MLClient
from azure.ai.ml.entities import Data, PipelineJob, Component
from azure.ai.ml.constants import AssetTypes
import requests # For calling REST endpoints

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Environment variables (passed from Synapse Spark job or Azure ML Pipeline)
AZURE_ML_WORKSPACE_NAME = os.environ.get("AZURE_ML_WORKSPACE_NAME")
RESOURCE_GROUP_NAME = os.environ.get("RESOURCE_GROUP_NAME")
SUBSCRIPTION_ID = os.environ.get("SUBSCRIPTION_ID")
AML_CLASSIFICATION_ENDPOINT_URL = os.environ.get("AML_CLASSIFICATION_ENDPOINT_URL") # For real-time endpoint
AML_CLASSIFICATION_ENDPOINT_KEY = os.environ.get("AML_CLASSIFICATION_ENDPOINT_KEY") # For real-time endpoint

def classify_data_batch(input_path, output_path):
    """
    Reads data from input_path, classifies it, and writes results to output_path.
    This function can be run as a Synapse Spark job or an Azure ML Pipeline component.
    """
    logger.info(f"Starting batch classification for input: {input_path}")

    # --- 1. Read input data (processed text/chunks from ADLS Gen2) ---
    # Assuming Parquet format from previous text extraction/chunking step
    df = spark.read.parquet(input_path).toPandas() # Convert to Pandas for local processing (adjust for large data)
    logger.info(f"Loaded {len(df)} records for classification.")

    # --- 2. Classify using Azure ML Endpoint or Azure Cognitive Services/OpenAI ---
    # This example calls a real-time AML endpoint. For very large batches,
    # consider AML Batch Endpoints or distributed processing directly within Spark.
    results = []
    for index, row in df.iterrows():
        text_to_classify = row['chunk'] # Assuming 'chunk' column has the text
        file_path = row['original_file_path']

        classification = 'Unknown'
        confidence = 0.0
        details = {}

        try:
            # Call AML Real-time Endpoint
            headers = {'Content-Type': 'application/json', 'Authorization': f'Bearer {AML_CLASSIFICATION_ENDPOINT_KEY}'}
            body = {"input_data": {"text": text_to_classify}} # Adjust input schema as per your AML endpoint
            response = requests.post(AML_CLASSIFICATION_ENDPOINT_URL, headers=headers, json=body)
            response.raise_for_status() # Raise an exception for HTTP errors
            aml_result = response.json()

            classification = aml_result.get('classification', 'Unknown')
            confidence = aml_result.get('confidence', 0.0)
            details = aml_result.get('details', {})

            logger.info(f"Classified {file_path} - Chunk: {index} as {classification} (Confidence: {confidence})")

        except requests.exceptions.RequestException as e:
            logger.error(f"Error calling AML Endpoint for {file_path} (chunk {index}): {e}")
            classification = 'Error'
            details = {'error': str(e)}
        except Exception as e:
            logger.error(f"Unexpected error during classification for {file_path} (chunk {index}): {e}")
            classification = 'Error'
            details = {'error': str(e)}

        results.append({
            'original_file_path': file_path,
            'chunk_index': index,
            'text_chunk': text_to_classify,
            'classification': classification,
            'confidence': confidence,
            'detection_details': details
        })

    df_results = pd.DataFrame(results)

    # --- 3. Save Classification Results ---
    # Save the results back to ADLS Gen2 in a structured format (e.g., Parquet).
    # This can then be consumed by the metadata-updater function or for audit/reporting.
    spark.createDataFrame(df_results).write.mode("append").parquet(output_path)
    logger.info(f"Classification results saved to: {output_path}")


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Batch classify data for Azure Data Lake Sentinel.")
    parser.add_argument("--input_path", type=str, help="Path to input data (e.g., ADLS Gen2 folder).")
    parser.add_argument("--output_path", type=str, help="Path to output classified data.")
    args = parser.parse_args()

    # In a Synapse Spark Notebook, 'spark' context is already available.
    # For running as an Azure ML component, ensure 'spark' is set up or remove pandas conversion.
    # For this example, assuming 'spark' is globally available if running in Synapse.
    # If running as AML component, you might directly use pandas and rely on AML's IO capabilities.

    classify_data_batch(args.input_path, args.output_path)
