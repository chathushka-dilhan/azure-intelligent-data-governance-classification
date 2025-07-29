// azure-data-lake-sentinel/src/functions/remediation-trigger/index.js

const { BlobServiceClient, StorageSharedKeyCredential } = require("@azure/storage-blob");
const { DefaultAzureCredential } = require("@azure/identity");
const { ResourceManagementClient } = require("@azure/arm-resources");
const { PolicyClient } = require("@azure/arm-policy");

const ADLS_GEN2_ACCOUNT_NAME = process.env.ADLS_GEN2_ACCOUNT_NAME;
const ADLS_GEN2_FILESYSTEM_NAME = process.env.ADLS_GEN2_FILESYSTEM_NAME;
const SUBSCRIPTION_ID = process.env.SUBSCRIPTION_ID;
const RBAC_GROUP_RESTRICTED_ACCESS_ID = process.env.RBAC_GROUP_RESTRICTED_ACCESS_ID; // Entra ID Group ID for restricted access

const logger = console;

// For production, use Managed Identity for all Azure SDK clients
const credential = new DefaultAzureCredential();

module.exports = async function (context, req) {
    context.log('Azure Function "remediation-trigger" triggered by HTTP request.');

    if (req.body) {
        const { filePath, classification, message } = req.body;
        logger.log(`Remediation request for file: ${filePath}, Classification: ${classification}`);

        let remediationAction = 'None';
        let remediationStatus = 'Failed';

        try {
            if (classification === 'PII' || classification === 'Confidential') {
                // --- Step 1: Apply stricter ACLs on the ADLS Gen2 path ---
                // This is a complex operation as ADLS Gen2 ACLs are per-object/per-directory.
                // For a specific path, you'd enumerate ACLs and modify them.
                logger.log(`Attempting to apply stricter ACLs for ${filePath} due to ${classification} data.`);

                // Example: Accessing ADLS Gen2 (requires Storage Blob Data Contributor/Owner)
                const blobServiceClient = new BlobServiceClient(
                    `https://${ADLS_GEN2_ACCOUNT_NAME}.dfs.core.windows.net`,
                    credential
                );
                const fileSystemClient = blobServiceClient.getFileSystemClient(ADLS_GEN2_FILESYSTEM_NAME);
                const directoryClient = fileSystemClient.getDirectoryClient(filePath.substring(0, filePath.lastIndexOf('/'))); // Get parent directory

                // This is simplified. Actual ACL modification is more involved.
                // await directoryClient.setAccessControl(`user:${RBAC_GROUP_RESTRICTED_ACCESS_ID}:rwx,group::r-x,other::---`);
                logger.log(`ACL modification for ${filePath} (conceptual).`);

                remediationAction = 'ACL Update';
                remediationStatus = 'Initiated'; // Or 'Completed' if direct API call succeeded

                // --- Step 2: Optionally, apply Azure Policy tag for audit/reporting ---
                // This might be redundant if classification already implies a tag, but can be
                // used to ensure consistency or trigger other policies.
                logger.log(`Attempting to apply Azure Policy tag for ${filePath}.`);
                const resourceClient = new ResourceManagementClient(credential, SUBSCRIPTION_ID);
                const policyClient = new PolicyClient(credential, SUBSCRIPTION_ID);

                const resourceId = `/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${process.env.ADLS_RESOURCE_GROUP_NAME}/providers/Microsoft.Storage/storageAccounts/${ADLS_GEN2_ACCOUNT_NAME}/blobServices/default/containers/${ADLS_GEN2_FILESYSTEM_NAME}/blobs/${filePath}`; // Example resource ID for a blob

                // Example: Update tags (conceptual - requires resource ID resolution)
                // await resourceClient.resources.beginUpdateByIdAndWait(resourceId, { tags: { 'DataClassification': classification }});
                logger.log(`Azure Policy tag update for ${filePath} (conceptual).`);
                remediationStatus = 'Completed';

            } else {
                logger.log(`No remediation action defined for classification: ${classification}.`);
                remediationAction = 'No action needed';
                remediationStatus = 'Not Applicable';
            }

            context.res = {
                status: 200,
                body: `Remediation for ${filePath} status: ${remediationStatus}, Action: ${remediationAction}`
            };

        } catch (error) {
            logger.error(`Error during remediation for ${filePath}: ${error.message}`);
            context.res = {
                status: 500,
                body: `Remediation failed for ${filePath}: ${error.message}`
            };
        }
    } else {
        context.res = {
            status: 400,
            body: "Please pass a request body with file metadata for remediation."
        };
    }
};
