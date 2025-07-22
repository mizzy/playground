"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const googleapis_1 = require("googleapis");
const google_auth_library_1 = require("google-auth-library");
const credential_providers_1 = require("@aws-sdk/credential-providers");
class AwsSupplier {
    constructor(region) {
        this.region = region;
    }
    async getAwsSecurityCredentials(context) {
        const awsCredentialsProvider = (0, credential_providers_1.fromNodeProviderChain)();
        const awsCredentials = await awsCredentialsProvider();
        return {
            accessKeyId: awsCredentials.accessKeyId,
            secretAccessKey: awsCredentials.secretAccessKey,
            token: awsCredentials.sessionToken
        };
    }
    async getAwsRegion(context) {
        return this.region;
    }
}
async function authenticateWithWorkloadIdentity() {
    const projectNumber = process.env.GCP_PROJECT_NUMBER;
    const projectId = process.env.GCP_PROJECT_ID || 'mizzy-270104';
    const poolId = process.env.WORKLOAD_IDENTITY_POOL_ID;
    const providerId = process.env.WORKLOAD_IDENTITY_PROVIDER_ID;
    const serviceAccountEmail = process.env.SERVICE_ACCOUNT_EMAIL;
    const region = process.env.AWS_REGION || 'ap-northeast-1';
    if (!projectNumber || !poolId || !providerId || !serviceAccountEmail) {
        throw new Error('Missing required environment variables for Workload Identity');
    }
    console.log('Workload Identity Configuration:');
    console.log(`  Project Number: ${projectNumber}`);
    console.log(`  Project ID: ${projectId}`);
    console.log(`  Pool ID: ${poolId}`);
    console.log(`  Provider ID: ${providerId}`);
    console.log(`  Service Account: ${serviceAccountEmail}`);
    console.log(`  Region: ${region}`);
    const audience = `//iam.googleapis.com/projects/${projectNumber}/locations/global/workloadIdentityPools/${poolId}/providers/${providerId}`;
    console.log(`  Audience: ${audience}`);
    // Service account impersonation is required for accessing Google APIs
    // Try using project ID instead of "-"
    const serviceAccountImpersonationUrl = `https://iamcredentials.googleapis.com/v1/projects/${projectId}/serviceAccounts/${serviceAccountEmail}/generateAccessToken`;
    console.log(`  Service Account Impersonation URL: ${serviceAccountImpersonationUrl}`);
    return new google_auth_library_1.AwsClient({
        audience,
        subject_token_type: 'urn:ietf:params:aws:token-type:aws4_request',
        service_account_impersonation_url: serviceAccountImpersonationUrl,
        aws_security_credentials_supplier: new AwsSupplier(region),
        scopes: ['https://www.googleapis.com/auth/spreadsheets']
    });
}
async function accessSpreadsheet(spreadsheetId, range) {
    try {
        console.log('Authenticating with Google Cloud Workload Identity...');
        const authClient = await authenticateWithWorkloadIdentity();
        const sheets = googleapis_1.google.sheets({ version: 'v4', auth: authClient });
        console.log(`Accessing spreadsheet ${spreadsheetId}, range: ${range}`);
        const response = await sheets.spreadsheets.values.get({
            spreadsheetId,
            range,
        });
        console.log('Spreadsheet data:');
        console.log(JSON.stringify(response.data.values, null, 2));
        // Example: Update a cell
        const updateRange = 'A1';
        const updateResponse = await sheets.spreadsheets.values.update({
            spreadsheetId,
            range: updateRange,
            valueInputOption: 'RAW',
            requestBody: {
                values: [[`Updated from AWS Fargate at ${new Date().toISOString()}`]],
            },
        });
        console.log(`Updated cell ${updateRange}: ${updateResponse.data.updatedCells} cells updated`);
    }
    catch (error) {
        console.error('Error accessing spreadsheet:', error);
        if (error.response) {
            console.error('Response status:', error.response.status);
            console.error('Response data:', error.response.data);
        }
        throw error;
    }
}
async function main() {
    const spreadsheetId = process.env.SPREADSHEET_ID || '1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms'; // Example spreadsheet
    const range = process.env.SPREADSHEET_RANGE || 'A1:B10';
    await accessSpreadsheet(spreadsheetId, range);
}
main().catch(console.error);
