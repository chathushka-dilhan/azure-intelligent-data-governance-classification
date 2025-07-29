# azure-data-lake-sentinel/scripts/simulate_data_upload.sh

#!/bin/bash

# This script simulates data uploads to an Azure Data Lake Storage Gen2 container.
# This will trigger the Event Grid subscription and initiate the classification workflow.

# Usage: ./simulate_data_upload.sh <ADLS_ACCOUNT_NAME> <ADLS_FILESYSTEM_NAME> <BLOB_PREFIX> [NUM_FILES]

# Check if Azure CLI is installed
if ! command -v az &> /dev/null
then
    echo "Azure CLI could not be found. Please install it to run this script."
    exit 1
fi

# Check for required arguments
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    echo "Usage: $0 <ADLS_ACCOUNT_NAME> <ADLS_FILESYSTEM_NAME> <BLOB_PREFIX> [NUM_FILES]"
    echo "Example: $0 adlsentineldev storage-data raw-docs 5"
    exit 1
fi

ADLS_ACCOUNT_NAME=$1
ADLS_FILESYSTEM_NAME=$2
BLOB_PREFIX=$3 # e.g., "raw-docs", "customer-data"
NUM_FILES=${4:-1} # Default to 1 file if not specified

echo "Simulating upload of ${NUM_FILES} files to ADLS Gen2..."
echo "Account: ${ADLS_ACCOUNT_NAME}"
echo "Filesystem (Container): ${ADLS_FILESYSTEM_NAME}"
echo "Prefix: ${BLOB_PREFIX}"

for i in $(seq 1 $NUM_FILES); do
    FILENAME="${BLOB_PREFIX}/sample_doc_$(date +%s%N)_${i}.txt"
    CONTENT="This is a sample document for testing data classification. It contains a random number: $(shuf -i 1000-9999 -n 1)."

    if (( i % 2 == 0 )); then
        # Introduce some "PII-like" content every other file
        RANDOM_NAME=$(cat /dev/urandom | tr -dc 'a-zA-Z' | head -c 8)
        RANDOM_SSN=$(printf "%03d-%02d-%04d" $((RANDOM%1000)) $((RANDOM%100)) $((RANDOM%10000)))
        RANDOM_EMAIL="${RANDOM_NAME}@example.com"
        CONTENT="${CONTENT}\nThis document may contain sensitive data, including PII. For example, a name like ${RANDOM_NAME}, an email address like ${RANDOM_EMAIL}, or a social security number like ${RANDOM_SSN}."
    fi

    echo -e "${CONTENT}" > /tmp/temp_upload_file.txt

    echo "Uploading ${FILENAME}..."
    az storage fs file upload \
        --account-name "${ADLS_ACCOUNT_NAME}" \
        --file-system "${ADLS_FILESYSTEM_NAME}" \
        --path "${FILENAME}" \
        --source "/tmp/temp_upload_file.txt" \
        --overwrite true > /dev/null

    if [ $? -eq 0 ]; then
        echo "Successfully uploaded ${FILENAME}"
    else
        echo "Failed to upload ${FILENAME}"
    fi

    rm /tmp/temp_upload_file.txt
    sleep 1 # Wait a bit between uploads
done

echo "Simulation complete."
