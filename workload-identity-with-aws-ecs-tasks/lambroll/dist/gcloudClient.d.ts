import { GoogleAuth, AwsClient } from "google-auth-library";
type GoogleAuthConfig = Readonly<{
    scopes?: string[];
    workloadIdentityPoolProjectNumber?: string;
    workloadIdentityPoolId?: string;
    workloadIdentityPoolProviderId?: string;
    serviceAccountEmail?: string;
    region?: string;
}>;
export declare const createGoogleAuth: (config: GoogleAuthConfig) => Promise<GoogleAuth | AwsClient>;
export {};
//# sourceMappingURL=gcloudClient.d.ts.map