# Lambda with GCP Workload Identity

This Lambda function demonstrates using GCP Workload Identity Federation to access Google Sheets from AWS Lambda.

## Prerequisites

1. Set up Workload Identity Pool and Provider in GCP
2. Create an IAM role for Lambda with appropriate permissions
3. Configure environment variables

## Environment Variables

- `GCP_PROJECT_NUMBER`: Your GCP project number
- `GCP_PROJECT_ID`: Your GCP project ID
- `WORKLOAD_IDENTITY_POOL_ID`: Workload Identity Pool ID
- `WORKLOAD_IDENTITY_PROVIDER_ID`: Workload Identity Provider ID
- `SERVICE_ACCOUNT_EMAIL`: GCP Service Account email to impersonate
- `AWS_REGION`: AWS region (defaults to ap-northeast-1)

## Build and Deploy

```bash
# Install dependencies
npm install

# Build TypeScript
npm run build

# Deploy with lambroll
lambroll deploy
```

## Update function configuration

```bash
# Update function.json with your IAM role ARN and environment variables
# Then deploy
lambroll deploy
```

## Test the function

The Lambda handler accepts spreadsheet parameters via query string or request body:

```json
{
  "spreadsheetId": "your-spreadsheet-id",
  "range": "A1:B10"
}
```