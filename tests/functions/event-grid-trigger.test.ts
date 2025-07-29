// This is a conceptual test file for the event-grid-trigger Azure Function.
// It demonstrates how you would mock dependencies to test the function's logic.

// Mock Azure SDK modules
jest.mock('@azure/event-hubs', () => ({
    EventHubProducerClient: jest.fn().mockImplementation(() => ({
        createBatch: jest.fn().mockResolvedValue({
            tryAdd: jest.fn().mockReturnValue(true)
        }),
        sendBatch: jest.fn().mockResolvedValue(void 0),
        close: jest.fn().mockResolvedValue(void 0)
    }))
}));

jest.mock('@azure/storage-blob', () => ({
    BlobServiceClient: jest.fn().mockImplementation(() => ({
        getContainerClient: jest.fn().mockReturnThis(),
        getBlobClient: jest.fn().mockReturnThis(),
        downloadToBuffer: jest.fn().mockResolvedValue(Buffer.from("Sample file content for testing"))
    }))
}));

jest.mock('@azure/identity', () => ({
    DefaultAzureCredential: jest.fn()
}));


// Import the function to be tested
const eventGridTrigger = require('../../src/functions/event-grid-trigger/index.js');
const { EventHubProducerClient } = require('@azure/event-hubs');
const { BlobServiceClient } = require('@azure/storage-blob');

describe('Event Grid Trigger Function', () => {
    // Mock the Azure Function context object
    const mockContext = {
        log: jest.fn(),
        done: jest.fn()
    };

    beforeEach(() => {
        // Reset mocks before each test
        jest.clearAllMocks();

        // Set up mock environment variables
        process.env.EVENT_HUB_NAMESPACE_NAME = 'testeventhubnamespace';
        process.env.EVENT_HUB_NAME = 'testeventhub';
        process.env.ADLS_GEN2_ACCOUNT_NAME = 'testadlsgen2';
        process.env.ADLS_GEN2_FILESYSTEM_NAME = 'test-data';
        process.env.EVENT_HUB_CONNECTION_STRING = 'Endpoint=sb://...'; // Only for testing without MI
    });

    it('should process BlobCreated event and send message to Event Hub', async () => {
        const mockEventGridEvent = {
            id: 'test-event-id',
            topic: '/subscriptions/sub-id/resourceGroups/rg-name/providers/Microsoft.Storage/storageAccounts/testadlsgen2',
            subject: '/blobServices/default/containers/test-data/blobs/raw/document.txt',
            data: {
                url: 'https://testadlsgen2.blob.core.windows.net/test-data/raw/document.txt',
                contentType: 'text/plain',
                contentLength: 1234,
                eTag: '0x8D98C1234567890',
                lastModified: '2024-01-01T00:00:00Z'
            },
            eventType: 'Microsoft.Storage.BlobCreated',
            eventTime: '2024-01-01T00:00:00Z',
            dataVersion: '1.0',
            metadataVersion: '1'
        };

        await eventGridTrigger(mockContext, mockEventGridEvent);

        // Expect function to log the event
        expect(mockContext.log).toHaveBeenCalledWith(
            'Azure Function "event-grid-trigger" triggered by Event Grid event:',
            mockEventGridEvent
        );
        expect(mockContext.log).toHaveBeenCalledWith(expect.stringContaining('Processing BlobCreated for blob:'));

        // Expect EventHubProducerClient to be instantiated and send a message
        expect(EventHubProducerClient).toHaveBeenCalledWith(
            process.env.EVENT_HUB_CONNECTION_STRING,
            process.env.EVENT_HUB_NAME
        );
        const producerClientInstance = EventHubProducerClient.mock.results[0].value;
        expect(producerClientInstance.createBatch).toHaveBeenCalledTimes(1);
        expect(producerClientInstance.sendBatch).toHaveBeenCalledTimes(1);
        expect(producerClientInstance.close).toHaveBeenCalledTimes(1);

        // Verify the content sent to Event Hub
        const sentMessage = JSON.parse(producerClientInstance.createBatch.mock.results[0].value.tryAdd.mock.calls[0][0].body);
        expect(sentMessage.filePath).toBe('raw/document.txt');
        expect(sentMessage.eventType).toBe('Microsoft.Storage.BlobCreated');
        expect(sentMessage.fileSize).toBe(1234);
    });

    it('should skip other event types', async () => {
        const mockEventGridEvent = {
            id: 'test-event-id',
            topic: '/subscriptions/sub-id/resourceGroups/rg-name/providers/Microsoft.Storage/storageAccounts/testadlsgen2',
            subject: '/blobServices/default/containers/test-data/blobs/image.jpg',
            data: {
                url: 'https://testadlsgen2.blob.core.windows.net/test-data/image.jpg',
                contentType: 'image/jpeg',
                contentLength: 5678
            },
            eventType: 'Microsoft.Storage.BlobDeleted', // Different event type
            eventTime: '2024-01-01T00:00:00Z',
            dataVersion: '1.0',
            metadataVersion: '1'
        };

        await eventGridTrigger(mockContext, mockEventGridEvent);

        expect(mockContext.log).toHaveBeenCalledWith(expect.stringContaining('Skipping event of type: Microsoft.Storage.BlobDeleted'));
        expect(EventHubProducerClient).not.toHaveBeenCalled(); // Should not send to Event Hub
    });

    it('should handle errors gracefully', async () => {
        // Mock EventHubProducerClient to throw an error
        EventHubProducerClient.mockImplementationOnce(() => ({
            createBatch: jest.fn().mockResolvedValue({
                tryAdd: jest.fn().mockReturnValue(true)
            }),
            sendBatch: jest.fn().mockRejectedValue(new Error('Event Hub send failed')),
            close: jest.fn().mockResolvedValue(void 0)
        }));

        const mockEventGridEvent = {
            id: 'test-event-id',
            topic: '/subscriptions/sub-id/resourceGroups/rg-name/providers/Microsoft.Storage/storageAccounts/testadlsgen2',
            subject: '/blobServices/default/containers/test-data/blobs/error_doc.txt',
            data: {
                url: 'https://testadlsgen2.blob.core.windows.net/test-data/error_doc.txt',
                contentType: 'text/plain',
                contentLength: 100
            },
            eventType: 'Microsoft.Storage.BlobCreated',
            eventTime: '2024-01-01T00:00:00Z',
            dataVersion: '1.0',
            metadataVersion: '1'
        };

        // Expect the function to throw an error, which will be caught by the Azure Functions host
        await expect(eventGridTrigger(mockContext, mockEventGridEvent)).rejects.toThrow('Event Hub send failed');
        expect(mockContext.log).toHaveBeenCalledWith(expect.stringContaining('Error sending message to Event Hub: Event Hub send failed'));
    });
});
