# IAM role for Lambda function with Workload Identity
resource "aws_iam_role" "lambda_workload_identity" {
  name = "lambda-workload-identity-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "lambda-workload-identity-role"
    Purpose     = "Lambda function with GCP Workload Identity"
    Environment = "production"
  }
}

# Attach basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_workload_identity.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Custom policy for Workload Identity
resource "aws_iam_role_policy" "lambda_workload_identity_policy" {
  name = "lambda-workload-identity-policy"
  role = aws_iam_role.lambda_workload_identity.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sts:GetCallerIdentity",
          "sts:GetSessionToken"
        ]
        Resource = "*"
      }
    ]
  })
}

# Output the role ARN for use in Lambda function configuration
output "lambda_workload_identity_role_arn" {
  description = "ARN of the Lambda Workload Identity IAM role"
  value       = aws_iam_role.lambda_workload_identity.arn
}