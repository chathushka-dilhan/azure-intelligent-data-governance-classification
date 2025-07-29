const axios = require('axios'); // For HTTP calls to Azure ML/Cognitive Services
const { DefaultAzureCredential } = require("@azure/identity");
const { SecretClient } = require("@azure/keyvault");

const SYNAPSE_WORKSPACE_NAME = process.env.SYNAPSE_WORKSPACE_NAME;
const AML_WORKSPACE_NAME = process.env.AML_WORKSPACE_NAME; // For AML endpoint invocation
const AML_CLASSIFICATION_ENDPOINT_URL = process.env.AML_CLASSIFICATION_ENDPOINT_URL; // Real-time endpoint URL
const COGNITIVE_SERVICES_ENDPOINT = process.env.COGNITIVE_SERVICES_ENDPOINT;
const COGNITIVE_SERVICES_KEY = process.env.COGNITIVE_SERVICES_KEY; // Use Key Vault for prod!
const AZURE_OPENAI_ENDPOINT = process.env.AZURE_OPENAI_ENDPOINT;
const AZURE_OPENAI_KEY = process.env.AZURE_OPENAI_KEY; // Use Key Vault for prod!
const COSMOSDB_DATABASE_NAME = process.env.COSMOSDB_DATABASE_NAME;
const COSMOSDB_CONTAINER_NAME = process.env.COSMOSDB_CONTAINER_NAME;
const METADATA_UPDATER_FUNCTION_URL = process.env.METADATA_UPDATER_FUNCTION_URL; // HTTP trigger URL for next function
const BEDROCK_PROMPT_CONTAINER_URL = process.env.BEDROCK_PROMPT_CONTAINER_URL; // S3 bucket for prompt templates
const BEDROCK_PROMPT_FILE_PATH = process.env.BEDROCK_PROMPT_FILE_PATH;

const logger = console;

// In a real scenario, consider using Key Vault for secrets and Managed Identity for service-to-service auth
// const keyVaultUrl = process.env.KEY_VAULT_URL;
// const credential = new DefaultAzureCredential();
// const secretClient = new SecretClient(keyVaultUrl, credential);

module.exports = async function (context, eventHubMessages) {
    context.log('Azure Function "classification-orchestrator" triggered by Event Hub message:', eventHubMessages);

    for (const message of eventHubMessages) {
        try {
            const fileInfo = JSON.parse(message);
            const { filePath, fileUrl, fileSize, eventType, timestamp } = fileInfo;
            logger.log(`Processing file: ${filePath}, Event Type: ${eventType}`);

            let extractedText = '';

            // --- Step 1: Trigger Synapse/Databricks for Text Extraction & Chunking ---
            // This would typically be an asynchronous call to a Synapse Spark job or Databricks Notebook.
            // For simplicity, we'll simulate text extraction or assume data is simple text for now.
            // In reality, you'd trigger a Synapse Spark Notebook here that reads the file,
            // extracts text (e.g., from PDF), and saves chunks to ADLS Gen2.
            logger.log(`Simulating text extraction for ${filePath}. In production, this triggers Synapse Spark.`);
            // Example of how you might trigger a Synapse Notebook via REST API (requires auth setup)
            /*
            const synapseApiUrl = `https://${SYNAPSE_WORKSPACE_NAME}.dev.azuresynapse.net/notebooks/<notebook-id>/execute?api-version=2020-12-01`;
            const synapseJobResponse = await axios.post(synapseApiUrl, {
                parameters: { filePath: fileUrl }
            }, {
                headers: { 'Authorization': `Bearer ${getSynapseAccessToken()}` }
            });
            // You'd then poll for job completion or get results from an S3 output
            */

            // For demonstration, let's assume we read the text directly if it's a small text file
            // In production, for large or binary files, you need a scalable text extraction mechanism.
            const blobServiceClient = new BlobServiceClient(fileUrl.split(filePath)[0], new DefaultAzureCredential());
            const containerClient = blobServiceClient.getContainerClient(ADLS_GEN2_FILESYSTEM_NAME);
            const blobClient = containerClient.getBlobClient(filePath);
            const downloadBlockBlobResponse = await blobClient.downloadToBuffer();
            extractedText = downloadBlockBlobResponse.toString(); // Assuming it's text
            logger.log(`Extracted text sample (first 100 chars): ${extractedText.substring(0, 100)}`);


            // --- Step 2: Classify Data using Azure ML Custom Model / Cognitive Services / Azure OpenAI ---
            let classificationResult = {
                classification: 'Unknown',
                confidence: 0.0,
                message: 'No specific classification detected.',
                detectionDetails: {}
            };

            // Option A: Custom ML Model (via Azure ML Endpoint)
            if (AML_CLASSIFICATION_ENDPOINT_URL) {
                logger.log('Calling Azure ML custom classification endpoint...');
                try {
                    const amlResponse = await axios.post(AML_CLASSIFICATION_ENDPOINT_URL, {
                        input_data: { "text": extractedText } // Input schema for your AML endpoint
                    }, {
                        headers: { 'Authorization': `Bearer ${getAmlAccessToken()}`, 'Content-Type': 'application/json' }
                    });
                    classificationResult = amlResponse.data;
                    logger.log('AML Classification Result:', classificationResult);
                } catch (amlError) {
                    logger.error(`Error calling AML endpoint: ${amlError.message}`);
                }
            }

            // Option B: Azure Cognitive Services (e.g., Text Analytics for PII)
            if (COGNITIVE_SERVICES_ENDPOINT && COGNITIVE_SERVICES_KEY) {
                logger.log('Calling Azure Cognitive Services for PII detection...');
                try {
                    const textAnalyticsUrl = `${COGNITIVE_SERVICES_ENDPOINT}/text/analytics/v3.1/pii`;
                    const cogSvcResponse = await axios.post(textAnalyticsUrl, {
                        documents: [{ id: "1", text: extractedText, language: "en" }]
                    }, {
                        headers: { 'Ocp-Apim-Subscription-Key': COGNITIVE_SERVICES_KEY, 'Content-Type': 'application/json' }
                    });

                    const piiEntities = cogSvcResponse.data.documents[0]?.entities;
                    if (piiEntities && piiEntities.length > 0) {
                        classificationResult.classification = 'PII';
                        classificationResult.confidence = 1.0; // Assume high confidence for direct detection
                        classificationResult.message = `PII detected: ${piiEntities.map(e => e.category).join(', ')}`;
                        classificationResult.detectionDetails.piiEntities = piiEntities;
                    }
                    logger.log('Cognitive Services PII Result:', piiEntities);
                } catch (cogSvcError) {
                    logger.error(`Error calling Cognitive Services: ${cogSvcError.message}`);
                }
            }

            // Option C: Azure OpenAI Service (for nuanced classification/summarization)
            if (AZURE_OPENAI_ENDPOINT && AZURE_OPENAI_KEY) {
                logger.log('Calling Azure OpenAI Service for nuanced classification...');
                try {
                    // Fetch prompt template from S3/ADLS
                    const promptBlobClient = new BlobServiceClient(BEDROCK_PROMPT_CONTAINER_URL, new DefaultAzureCredential())
                        .getContainerClient(ADLS_GEN2_FILESYSTEM_NAME)
                        .getBlobClient(BEDROCK_PROMPT_FILE_PATH);
                    const promptDownloadResponse = await promptBlobClient.downloadToBuffer();
                    const promptTemplate = promptDownloadResponse.toString();

                    const prompt = promptTemplate.replace('{{text}}', extractedText);

                    const openAiUrl = `${AZURE_OPENAI_ENDPOINT}/openai/deployments/your-deployment-name/chat/completions?api-version=2023-05-15`; // Replace with your deployment name
                    const openAiResponse = await axios.post(openAiUrl, {
                        messages: [
                            { role: "system", content: "You are an expert data classifier." },
                            { role: "user", content: prompt }
                        ],
                        max_tokens: 200,
                        temperature: 0.7
                    }, {
                        headers: { 'api-key': AZURE_OPENAI_KEY, 'Content-Type': 'application/json' }
                    });

                    const openAiClassification = openAiResponse.data.choices[0]?.message?.content;
                    if (openAiClassification) {
                        // Parse OpenAI's response (e.g., expect JSON or specific keywords)
                        if (openAiClassification.includes("Classification: PII")) {
                             classificationResult.classification = 'PII';
                             classificationResult.confidence = Math.max(classificationResult.confidence, 0.9);
                             classificationResult.message = "OpenAI detected PII.";
                             classificationResult.detectionDetails.openAIResponse = openAiClassification;
                        } else if (openAiClassification.includes("Classification: Confidential")) {
                            classificationResult.classification = 'Confidential';
                            classificationResult.confidence = Math.max(classificationResult.confidence, 0.8);
                            classificationResult.message = "OpenAI detected confidential information.";
                            classificationResult.detectionDetails.openAIResponse = openAiClassification;
                        }
                        // Further parse for suggested tags, summary, etc.
                    }
                    logger.log('OpenAI Classification Response:', openAiClassification);
                } catch (openAiError) {
                    logger.error(`Error calling Azure OpenAI Service: ${openAiError.message}`);
                }
            }

            // --- Step 3: Send Classification Results to Metadata Updater Function ---
            logger.log('Sending classification result to metadata updater function...');
            const metadataPayload = {
                filePath: filePath,
                fileUrl: fileUrl,
                fileSize: fileSize,
                classification: classificationResult.classification,
                confidence: classificationResult.confidence,
                detectionDetails: classificationResult.detectionDetails,
                analysisTimestamp: new Date().toISOString()
            };

            try {
                const updateResponse = await axios.post(METADATA_UPDATER_FUNCTION_URL, metadataPayload);
                logger.log('Metadata updater function response:', updateResponse.status);
            } catch (updateError) {
                logger.error(`Error calling metadata updater function: ${updateError.message}`);
            }

        } catch (error) {
            logger.error(`Error processing message from Event Hub: ${message}, Error: ${error.message}`);
            // Depending on desired retry behavior, you might throw the error here
            // to allow Event Hubs to retry the message.
        }
    }
};

// Helper function to get access token (conceptual, needs implementation for production)
async function getAmlAccessToken() {
    // In production, use Managed Identity for AML endpoint authentication
    // For local testing, you might use az login or service principal
    return "YOUR_AML_ACCESS_TOKEN"; // Replace with actual token retrieval
}
