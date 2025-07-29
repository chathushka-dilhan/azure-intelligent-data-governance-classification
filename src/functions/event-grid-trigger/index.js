const { EventHubProducerClient } = require("@azure/event-hubs");
const { DefaultAzureCredential } = require("@azure/identity");
const { BlobServiceClient } = require("@azure/storage-blob");

const EVENT_HUB_NAMESPACE_NAME = process.env.EVENT_HUB_NAMESPACE_NAME;
const EVENT_HUB_NAME = process.env.EVENT_HUB_NAME;
const ADLS_GEN2_ACCOUNT_NAME = process.env.ADLS_GEN2_ACCOUNT_NAME;
const ADLS_GEN2_FILESYSTEM_NAME = process.env.ADLS_GEN2_FILESYSTEM_NAME; // Main container
const EVENT_HUB_CONNECTION_STRING = process.env.EVENT_HUB_CONNECTION_STRING; // For simplicity in dev, use connection string

const logger = console; // Using console for Azure Functions logging

module.exports = async function (context, eventGridEvent) {
    context.log('Azure Function "event-grid-trigger" triggered by Event Grid event:', eventGridEvent);

    try {
        const eventData = eventGridEvent.data;
        const eventType = eventGridEvent.eventType;
        const subject = eventGridEvent.subject; // e.g., /blobServices/default/containers/adlsentinel-data/blobs/raw/document.txt
        const url = eventData.url; // Full URL to the blob

        // We are interested in BlobCreated and BlobUpdated events
        if (eventType === "Microsoft.Storage.BlobCreated" || eventType === "Microsoft.Storage.BlobUpdated") {
            logger.log(`Processing ${eventType} for blob: ${url}`);

            const filePath = url.split(`/${ADLS_GEN2_FILESYSTEM_NAME}/`)[1]; // Get path relative to container
            if (!filePath) {
                logger.error(`Could not parse file path from URL: ${url}`);
                return;
            }

            // --- Step 1: Extract basic metadata from the event ---
            const fileInfo = {
                filePath: filePath,
                fileUrl: url,
                fileSize: eventData.contentLength,
                eTag: eventData.eTag,
                lastModified: eventData.lastModified,
                eventType: eventType,
                timestamp: new Date().toISOString()
            };

            logger.log('File info extracted:', fileInfo);

            // --- Step 2: Push a message to Event Hub for further processing ---
            // This message will be consumed by the 'classification-orchestrator' function.
            let producerClient;
            try {
                if (EVENT_HUB_CONNECTION_STRING) {
                    producerClient = new EventHubProducerClient(EVENT_HUB_CONNECTION_STRING, EVENT_HUB_NAME);
                } else {
                    // Use DefaultAzureCredential for production environments (Managed Identity)
                    const credential = new DefaultAzureCredential();
                    producerClient = new EventHubProducerClient(`${EVENT_HUB_NAMESPACE_NAME}.servicebus.windows.net`, EVENT_HUB_NAME, credential);
                }

                const batch = await producerClient.createBatch();
                batch.tryAdd({ body: JSON.stringify(fileInfo) });
                await producerClient.sendBatch(batch);
                logger.log(`Sent message to Event Hub '${EVENT_HUB_NAME}' for file: ${filePath}`);
            } catch (ehError) {
                logger.error(`Error sending message to Event Hub: ${ehError.message}`);
                throw ehError; // Rethrow to mark as failed
            } finally {
                if (producerClient) {
                    await producerClient.close();
                }
            }
        } else {
            logger.log(`Skipping event of type: ${eventType}`);
        }

    } catch (error) {
        logger.error('An error occurred during function execution:', error);
        // Throwing an error will cause Event Grid to retry the event, up to its configured retry policy.
        throw error;
    }
};
