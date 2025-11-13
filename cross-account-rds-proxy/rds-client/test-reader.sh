#!/bin/bash
aws-vault exec rds-client -- aws ecs run-task \
  --cluster rds-client-cluster \
  --task-definition rds-proxy-test \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-08362ba08f835d610,subnet-0446f8a5b55cc82ac],securityGroups=[sg-0ffc5759544e85c0d],assignPublicIp=DISABLED}" \
  --overrides file:///dev/stdin <<JSON | jq -r '.tasks[0].taskArn'
{
  "containerOverrides": [{
    "name": "postgres-client",
    "environment": [
      {"name": "DB_HOST", "value": "snra-05034c791f2126cd3.rcfg-0c5cf3eaea7a0bc7f.4232ccc.vpc-lattice-rsc.ap-northeast-1.on.aws"},
      {"name": "DB_PORT", "value": "5432"},
      {"name": "DB_NAME", "value": "mydb"},
      {"name": "DB_USER", "value": "postgres"},
      {"name": "DB_PASSWORD", "value": "change-me-later"}
    ]
  }]
}
JSON
