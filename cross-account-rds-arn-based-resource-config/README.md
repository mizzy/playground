# Cross-Account RDS with ARN-based Resource Configuration

This project demonstrates cross-account RDS access using VPC Lattice Resource Gateway with ARN-based Resource Configuration.

## Architecture

```
┌─────────────────────────────────────┐      ┌─────────────────────────────────────┐
│  rds-proxy Account                  │      │  rds-client Account                 │
│                                     │      │                                     │
│  ┌──────────────────────────────┐  │      │  ┌──────────────────────────────┐  │
│  │ VPC (10.1.0.0/16)            │  │      │  │ VPC (10.0.0.0/16)            │  │
│  │                              │  │      │  │                              │  │
│  │  ┌────────────────────────┐  │  │      │  │  ┌────────────────────────┐  │  │
│  │  │ Aurora PostgreSQL      │  │  │      │  │  │ ECS Task               │  │  │
│  │  │ (Cluster + Instance)   │  │  │      │  │  │ (PostgreSQL Client)    │  │  │
│  │  └────────────────────────┘  │  │      │  │  └────────────────────────┘  │  │
│  │            │                 │  │      │  │            │                 │  │
│  │            │                 │  │      │  │            │                 │  │
│  │  ┌─────────▼──────────────┐  │  │      │  │  ┌─────────▼──────────────┐  │  │
│  │  │ Resource Gateway       │  │  │      │  │  │ Service Network        │  │  │
│  │  │                        │  │  │      │  │  │                        │  │  │
│  │  │ ┌────────────────────┐ │  │  │      │  │  │ ┌────────────────────┐ │  │  │
│  │  │ │ARN-based Resource  │ │  │  │      │  │  │ │Service Network     │ │  │  │
│  │  │ │Configuration       │ │  │  │      │  │  │ │Resource Association│ │  │  │
│  │  │ │(RDS Cluster ARN)   │─┼──┼──┼──────┼──┼──┼─│(Shared Config)     │ │  │  │
│  │  │ └────────────────────┘ │  │  │      │  │  │ └────────────────────┘ │  │  │
│  │  └────────────────────────┘  │  │      │  │  └────────────────────────┘  │  │
│  │                              │  │      │  │                              │  │
│  └──────────────────────────────┘  │      │  └──────────────────────────────┘  │
│                                     │      │                                     │
│  RAM Resource Share                │      │                                     │
│  └─────────────────────────────────┼──────┼─> Shared to rds-client account     │
│                                     │      │                                     │
└─────────────────────────────────────┘      └─────────────────────────────────────┘
```

## Key Differences from Domain-Name Based Configuration

### ARN-based Configuration (This Project)
- Resource Configuration references the RDS cluster by ARN
- Direct ARN-to-ARN mapping
- Simpler configuration
- Works with any AWS resource that has an ARN

### Domain-Name Based Configuration (Previous Project)
- Resource Configuration references RDS endpoint by domain name
- DNS resolution required
- Used for RDS Proxy endpoints
- More flexible for non-AWS resources

## Deployment Steps

### 1. Deploy rds-proxy infrastructure

```bash
cd rds-proxy
terraform init
terraform apply
```

This creates:
- VPC with subnets
- Aurora PostgreSQL cluster
- VPC Lattice Resource Gateway
- ARN-based Resource Configuration
- RAM resource share

### 2. Get Resource Configuration ID

```bash
terraform output resource_configuration_id
```

Copy the output (e.g., `rcfg-xxxxxxxxxxxxxxxxx`)

### 3. Update rds-client configuration

Edit `rds-client/service_network.tf` and replace `PLACEHOLDER_RESOURCE_CONFIG_ID` with the actual Resource Configuration ID:

```terraform
resource "aws_vpclattice_service_network_resource_association" "rds_cluster" {
  resource_configuration_identifier = "rcfg-xxxxxxxxxxxxxxxxx"  # Replace this
  service_network_identifier        = aws_vpclattice_service_network.main.id
  ...
}
```

### 4. Deploy rds-client infrastructure

```bash
cd ../rds-client
terraform init
terraform apply
```

This creates:
- VPC with subnets
- VPC Lattice Service Network
- Service Network Resource Association (accepts the shared configuration)
- ECS cluster and task definition

### 5. Test the connection

Start an ECS task:

```bash
aws-vault exec rds-client -- aws ecs run-task \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --task-definition postgres-client \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$(terraform output -json subnet_ids | jq -r '.[0]')],securityGroups=[$(terraform output -raw ecs_security_group_id)],assignPublicIp=DISABLED}"
```

Get the task ID and connect to it:

```bash
TASK_ID=$(aws-vault exec rds-client -- aws ecs list-tasks \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --query 'taskArns[0]' --output text | awk -F/ '{print $NF}')

aws-vault exec rds-client -- aws ecs execute-command \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --task "$TASK_ID" \
  --container postgres-client \
  --interactive \
  --command "/bin/bash"
```

Inside the container, get the RDS endpoint from rds-proxy account and test connection:

```bash
# Get the endpoint from rds-proxy terraform output
RDS_ENDPOINT="<from rds-proxy terraform output rds_cluster_endpoint>"

psql -h "$RDS_ENDPOINT" -U postgres -d testdb
# Password: password123
```

## Cleanup

```bash
# Destroy rds-client first
cd rds-client
terraform destroy

# Then destroy rds-proxy
cd ../rds-proxy
terraform destroy
```

## Resources Created

### rds-proxy Account
- 1 VPC
- 2 Subnets
- 1 Security Group
- 1 Aurora PostgreSQL Cluster
- 1 Aurora Instance
- 1 VPC Lattice Resource Gateway
- 1 ARN-based Resource Configuration
- 1 RAM Resource Share

### rds-client Account
- 1 VPC
- 2 Subnets
- 1 Security Group
- 1 VPC Lattice Service Network
- 1 Service Network VPC Association
- 1 Service Network Resource Association
- 1 ECS Cluster
- 1 ECS Task Definition
- IAM Roles for ECS
