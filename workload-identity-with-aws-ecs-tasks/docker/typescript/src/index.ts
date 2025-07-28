import {google} from 'googleapis';
import {
    GoogleAuth,
    AwsClient,
    AwsSecurityCredentials,
    AwsSecurityCredentialsSupplier,
    ExternalAccountSupplierContext
} from 'google-auth-library';
import {fromNodeProviderChain} from '@aws-sdk/credential-providers';
import * as fs from 'fs/promises';

class AwsSupplier implements AwsSecurityCredentialsSupplier {
    private region: string;

    constructor(region: string) {
        this.region = region;
    }

    async getAwsSecurityCredentials(context: ExternalAccountSupplierContext): Promise<AwsSecurityCredentials> {
        const awsCredentialsProvider = fromNodeProviderChain();
        const awsCredentials = await awsCredentialsProvider();

        console.log('AWS Credentials obtained from provider chain:');
        console.log(`  AccessKeyId: ${awsCredentials.accessKeyId?.substring(0, 10)}...`);
        console.log(`  SessionToken exists: ${!!awsCredentials.sessionToken}`);

        return {
            accessKeyId: awsCredentials.accessKeyId,
            secretAccessKey: awsCredentials.secretAccessKey,
            token: awsCredentials.sessionToken
        };
    }

    async getAwsRegion(context: ExternalAccountSupplierContext): Promise<string> {
        return this.region;
    }
}

async function authenticateWithWorkloadIdentity() {
    const projectNumber = process.env.GCP_PROJECT_NUMBER;
    const projectId = process.env.GCP_PROJECT_ID;
    const poolId = process.env.WORKLOAD_IDENTITY_POOL_ID;
    const providerId = process.env.WORKLOAD_IDENTITY_PROVIDER_ID;
    const serviceAccountEmail = process.env.SERVICE_ACCOUNT_EMAIL;
    const region = process.env.AWS_REGION || 'ap-northeast-1';

    if (!projectNumber || !projectId || !poolId || !providerId || !serviceAccountEmail) {
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

    // Service account impersonation URL
    const serviceAccountImpersonationUrl = `https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/${serviceAccountEmail}:generateAccessToken`;
    console.log(`  Service Account Impersonation URL: ${serviceAccountImpersonationUrl}`);

    // Create AwsClient with custom AWS credentials supplier
    const client = new AwsClient({
        audience,
        subject_token_type: 'urn:ietf:params:aws:token-type:aws4_request',
        service_account_impersonation_url: serviceAccountImpersonationUrl,
        aws_security_credentials_supplier: new AwsSupplier(region),
        scopes: ['https://www.googleapis.com/auth/spreadsheets']
    });

    // Try to get access token to verify authentication
    try {
        console.log('Attempting to get access token...');
        const token = await client.getAccessToken();
        console.log('Access token obtained successfully');
        console.log(`Token: ${token.token?.substring(0, 20)}...`);
        return client;
    } catch (error: any) {
        console.error('Failed to get access token:', error.message);
        if (error.response) {
            console.error('Error response status:', error.response.status);
            console.error('Error response data:', error.response.data);
        }
        throw error;
    }
}

async function authenticateWithGcloud() {
    console.log('Using gcloud auth credentials...');

    const projectId = process.env.GCP_PROJECT_ID;

    // Create GoogleAuth instance that will use Application Default Credentials
    const auth = new GoogleAuth({
        scopes: ['https://www.googleapis.com/auth/spreadsheets'],
        clientOptions: {
            quotaProjectId: projectId
        }
    });

    try {
        const client = await auth.getClient();
        console.log('Successfully authenticated with gcloud credentials');
        console.log(`  Quota Project ID: ${projectId}`);
        return auth;
    } catch (error: any) {
        console.error('Failed to authenticate with gcloud:', error.message);
        throw error;
    }
}

async function isRunningOnAWS(): Promise<boolean> {
    // Check if we're running on ECS by looking for ECS-specific environment variables
    return !!(process.env.ECS_CONTAINER_METADATA_URI ||
        process.env.ECS_CONTAINER_METADATA_URI_V4 ||
        process.env.AWS_EXECUTION_ENV?.includes('ECS'));
}

async function accessSpreadsheet(spreadsheetId: string, range: string) {
    try {
        let authClient;

        if (await isRunningOnAWS()) {
            console.log('Running on AWS - using Workload Identity...');
            authClient = await authenticateWithWorkloadIdentity();
        } else {
            console.log('Not running on AWS - using gcloud auth...');
            authClient = await authenticateWithGcloud();
        }

        const sheets = google.sheets({version: 'v4', auth: authClient});

        console.log(`Accessing spreadsheet ${spreadsheetId}, range: ${range}`);
        const response = await sheets.spreadsheets.values.get({
            spreadsheetId,
            range,
        });

        console.log('Spreadsheet data:');
        console.log(JSON.stringify(response.data.values, null, 2));

    } catch (error: any) {
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