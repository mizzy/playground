import {fromNodeProviderChain} from '@aws-sdk/credential-providers'
import {
  AwsClient,
  AwsSecurityCredentials,
  AwsSecurityCredentialsSupplier,
  GoogleAuth,
} from 'google-auth-library'

type GoogleAuthConfig = Readonly<{
  scopes?: string[]
  workloadIdentityPoolProjectNumber?: string
  workloadIdentityPoolId?: string
  workloadIdentityPoolProviderId?: string
  serviceAccountEmail?: string
  awsRegion?: string
}>

const AwsSupplier = {
  from: (region: string): AwsSecurityCredentialsSupplier => ({
    async getAwsSecurityCredentials(): Promise<AwsSecurityCredentials> {
      const awsCredentialsProvider = fromNodeProviderChain()
      const awsCredentials = await awsCredentialsProvider()

      return {
        accessKeyId: awsCredentials.accessKeyId,
        secretAccessKey: awsCredentials.secretAccessKey,
        token: awsCredentials.sessionToken,
      }
    },

    async getAwsRegion(): Promise<string> {
      return region
    },
  }),
} as const

const isRunningOnLambda = (): boolean => process.env.DM_COMPUTING_TYPE?.toLowerCase() === 'lambda'

export const createGoogleAuth = async (
  config: GoogleAuthConfig,
): Promise<GoogleAuth | AwsClient> => {
  const {
    scopes,
    workloadIdentityPoolProjectNumber,
    workloadIdentityPoolId,
    workloadIdentityPoolProviderId,
    serviceAccountEmail,
    awsRegion,
  } = config

  const authScopes = scopes ?? ['https://www.googleapis.com/auth/spreadsheets']

  if (!isRunningOnLambda()) {
    // 非Lambda環境ではgcloud auth認証情報を使用
    return new GoogleAuth({
      scopes: authScopes,
    })
  }

  // Lambda環境ではWorkload Identityを使用
  if (
    !workloadIdentityPoolProjectNumber
    || !workloadIdentityPoolId
    || !workloadIdentityPoolProviderId
    || !serviceAccountEmail
  ) {
    throw new Error(
      'AWS Lambda環境で必要なWorkload Identity設定が不足しています',
    )
  }

  const audience =
    `//iam.googleapis.com/projects/${workloadIdentityPoolProjectNumber}/locations/global/workloadIdentityPools/${workloadIdentityPoolId}/providers/${workloadIdentityPoolProviderId}`
  const serviceAccountImpersonationUrl =
    `https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/${serviceAccountEmail}:generateAccessToken`

  return new AwsClient({
    audience,
    subject_token_type: 'urn:ietf:params:aws:token-type:aws4_request',
    service_account_impersonation_url: serviceAccountImpersonationUrl,
    aws_security_credentials_supplier: AwsSupplier.from(awsRegion || 'ap-northeast-1'),
    scopes: authScopes,
  })
}
