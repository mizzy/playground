import {
  GoogleAuth,
  AwsClient,
  AwsSecurityCredentials,
  AwsSecurityCredentialsSupplier,
  ExternalAccountSupplierContext,
} from "google-auth-library";
import { fromNodeProviderChain } from "@aws-sdk/credential-providers";

type GoogleAuthConfig = Readonly<{
  scopes?: string[];
  workloadIdentityPoolProjectNumber?: string;
  workloadIdentityPoolId?: string;
  workloadIdentityPoolProviderId?: string;
  serviceAccountEmail?: string;
  region?: string;
}>;

class AwsSupplier implements AwsSecurityCredentialsSupplier {
  private readonly region: string;

  constructor(region: string) {
    this.region = region;
  }

  async getAwsSecurityCredentials(
    context: ExternalAccountSupplierContext,
  ): Promise<AwsSecurityCredentials> {
    const awsCredentialsProvider = fromNodeProviderChain();
    const awsCredentials = await awsCredentialsProvider();

    return {
      accessKeyId: awsCredentials.accessKeyId,
      secretAccessKey: awsCredentials.secretAccessKey,
      token: awsCredentials.sessionToken,
    };
  }

  async getAwsRegion(context: ExternalAccountSupplierContext): Promise<string> {
    return this.region;
  }
}

const isRunningOnLambda = (): boolean => {
  return !!(
    process.env.AWS_LAMBDA_FUNCTION_NAME || process.env.LAMBDA_TASK_ROOT
  );
};

export const createGoogleAuth = async (
  config: GoogleAuthConfig,
): Promise<GoogleAuth | AwsClient> => {
  const {
    scopes,
    workloadIdentityPoolProjectNumber,
    workloadIdentityPoolId,
    workloadIdentityPoolProviderId,
    serviceAccountEmail,
    region,
  } = config;

  const authScopes = scopes || ["https://www.googleapis.com/auth/spreadsheets"];
  const awsRegion = region || "ap-northeast-1";

  if (isRunningOnLambda()) {
    // Lambda環境ではWorkload Identityを使用
    if (
      !workloadIdentityPoolProjectNumber ||
      !workloadIdentityPoolId ||
      !workloadIdentityPoolProviderId ||
      !serviceAccountEmail
    ) {
      throw new Error(
        "Missing required Workload Identity configuration for Lambda environment",
      );
    }

    const audience = `//iam.googleapis.com/projects/${workloadIdentityPoolProjectNumber}/locations/global/workloadIdentityPools/${workloadIdentityPoolId}/providers/${workloadIdentityPoolProviderId}`;
    const serviceAccountImpersonationUrl = `https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/${serviceAccountEmail}:generateAccessToken`;

    return new AwsClient({
      audience,
      subject_token_type: "urn:ietf:params:aws:token-type:aws4_request",
      service_account_impersonation_url: serviceAccountImpersonationUrl,
      aws_security_credentials_supplier: new AwsSupplier(awsRegion),
      scopes: authScopes,
    });
  } else {
    // 非Lambda環境ではgcloud auth認証情報を使用
    return new GoogleAuth({
      scopes: authScopes,
    });
  }
};
