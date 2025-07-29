"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.createGoogleAuth = void 0;
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
const isRunningOnLambda = () => {
    return !!(process.env.AWS_LAMBDA_FUNCTION_NAME || process.env.LAMBDA_TASK_ROOT);
};
const createGoogleAuth = async (config) => {
    const { scopes, workloadIdentityPoolProjectNumber, workloadIdentityPoolId, workloadIdentityPoolProviderId, serviceAccountEmail, region } = config;
    const authScopes = scopes || ['https://www.googleapis.com/auth/spreadsheets'];
    const awsRegion = region || 'ap-northeast-1';
    if (isRunningOnLambda()) {
        // Lambda環境ではWorkload Identityを使用
        if (!workloadIdentityPoolProjectNumber || !workloadIdentityPoolId || !workloadIdentityPoolProviderId || !serviceAccountEmail) {
            throw new Error('Missing required Workload Identity configuration for Lambda environment');
        }
        const audience = `//iam.googleapis.com/projects/${workloadIdentityPoolProjectNumber}/locations/global/workloadIdentityPools/${workloadIdentityPoolId}/providers/${workloadIdentityPoolProviderId}`;
        const serviceAccountImpersonationUrl = `https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/${serviceAccountEmail}:generateAccessToken`;
        return new google_auth_library_1.AwsClient({
            audience,
            subject_token_type: 'urn:ietf:params:aws:token-type:aws4_request',
            service_account_impersonation_url: serviceAccountImpersonationUrl,
            aws_security_credentials_supplier: new AwsSupplier(awsRegion),
            scopes: authScopes
        });
    }
    else {
        // 非Lambda環境ではgcloud auth認証情報を使用
        return new google_auth_library_1.GoogleAuth({
            scopes: authScopes
        });
    }
};
exports.createGoogleAuth = createGoogleAuth;
//# sourceMappingURL=gcloudClient.js.map