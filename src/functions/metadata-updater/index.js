const { CosmosClient } = require("@azure/cosmos");
const axios = require('axios'); // For calling Logic App

const COSMOSDB_ENDPOINT = process.env.COSMOSDB_ENDPOINT;
const COSMOSDB_PRIMARY_KEY = process.env.COSMOSDB_PRIMARY_KEY;
const COSMOSDB_DATABASE_NAME = process.env.COSMOSDB_DATABASE_NAME;
const COSMOSDB_CONTAINER_NAME = process.env.COSMOSDB_CONTAINER_NAME;
const LOGIC_APP_HTTP_TRIGGER_URL = process.env.LOGIC_APP_HTTP_TRIGGER_URL; // For triggering alerts

const logger = console;

const client = new CosmosClient({ endpoint: COSMOSDB_ENDPOINT, key: COSMOSDB_PRIMARY_KEY });
const database = client.database(COSMOSDB_DATABASE_NAME);
const container = database.container(COSMOSDB_CONTAINER_NAME);

module.exports = async function (context, req) {
    context.log('Azure Function "metadata-updater" triggered by HTTP request.');

    if (req.body) {
        const { filePath, fileUrl, fileSize, classification, confidence, detectionDetails, analysisTimestamp } = req.body;

        const item = {
            id: Buffer.from(filePath).toString('base64'), // Use base64 encoded path as ID for uniqueness and validity
            filePath,
            fileUrl,
            fileSize,
            classification,
            confidence,
            detectionDetails,
            analysisTimestamp,
            lastUpdated: new Date().toISOString()
        };

        try {
            // Upsert the item into Cosmos DB
            const { resource: createdItem } = await container.upsert(item);
            logger.log(`Upserted metadata for ${filePath} with classification ${classification}.`);
            context.res = {
                status: 200,
                body: `Metadata updated for ${filePath}`
            };

            // --- Step 2: Trigger Alerting Logic App for Highly Sensitive Data ---
            // You can define thresholds or specific classifications that warrant an alert.
            if (classification === 'PII' || classification === 'Confidential' && confidence > 0.8) {
                logger.log(`Highly sensitive data (${classification}) detected for ${filePath}. Triggering Logic App.`);
                const alertPayload = {
                    filePath,
                    classification,
                    confidence,
                    message: `Sensitive data classified as '${classification}' detected.`,
                    detectionDetails: JSON.stringify(detectionDetails, null, 2)
                };
                try {
                    await axios.post(LOGIC_APP_HTTP_TRIGGER_URL, alertPayload);
                    logger.log('Logic App notification triggered successfully.');
                } catch (logicAppError) {
                    logger.error(`Error triggering Logic App: ${logicAppError.message}`);
                }
            }

        } catch (error) {
            logger.error(`Error updating Cosmos DB or triggering Logic App for ${filePath}: ${error.message}`);
            context.res = {
                status: 500,
                body: `Error processing request: ${error.message}`
            };
        }
    } else {
        context.res = {
            status: 400,
            body: "Please pass a request body with file metadata."
        };
    }
};
