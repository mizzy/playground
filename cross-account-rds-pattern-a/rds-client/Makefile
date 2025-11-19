# Makefile for Pattern A RDS Client Testing Infrastructure

# Variables
AWS_PROFILE := rds-client
AWS_REGION := ap-northeast-1
AWS_ACCOUNT_ID := 914357407416
ECR_REPO := pattern-a-postgres-client
ECS_CLUSTER := pattern-a-test-cluster
TASK_FAMILY := pattern-a-postgres-test
POSTGRES_VERSION := 15

# ECR image URIs
ECR_URI := $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(ECR_REPO)

# IMPORTANT: AWS Fargate requires amd64 architecture
# On M1/M2 Macs, --platform flag doesn't always work correctly
# Use digest-based pull to ensure correct architecture

.PHONY: help
help:
	@echo "Available targets:"
	@echo "  docker-build          - Build and push amd64 postgres image to ECR"
	@echo "  docker-clean          - Remove local docker images"
	@echo "  ecs-register          - Register all test task definitions"
	@echo "  ecs-register-aurora   - Register Aurora cluster test task definition"
	@echo "  ecs-register-aurora-reader - Register Aurora reader test task definition"
	@echo "  ecs-register-proxy-writer - Register RDS Proxy writer test task definition"
	@echo "  ecs-register-proxy-reader - Register RDS Proxy reader test task definition"
	@echo "  ecs-stop              - Stop all running tasks"
	@echo "  ecs-logs              - Tail ECS task logs"
	@echo "  test-aurora           - Test Aurora cluster connection (runs task, waits, shows logs)"
	@echo "  test-aurora-reader    - Test Aurora reader endpoint connection (runs task, waits, shows logs)"
	@echo "  test-proxy-writer     - Test RDS Proxy writer endpoint (runs task, waits, shows logs)"
	@echo "  test-proxy-reader     - Test RDS Proxy reader endpoint (runs task, waits, shows logs)"
	@echo "  test-all              - Run all connection tests sequentially"

.PHONY: docker-build
docker-build:
	@echo "==> Getting amd64 digest for postgres:$(POSTGRES_VERSION)"
	$(eval AMD64_DIGEST := $(shell docker manifest inspect postgres:$(POSTGRES_VERSION) | jq -r '.manifests[] | select(.platform.architecture=="amd64" and .platform.os=="linux") | .digest'))
	@echo "==> AMD64 Digest: $(AMD64_DIGEST)"
	@echo "==> Pulling amd64 image by digest"
	docker pull postgres@$(AMD64_DIGEST)
	@echo "==> Tagging image"
	docker tag postgres@$(AMD64_DIGEST) $(ECR_URI):amd64
	docker tag postgres@$(AMD64_DIGEST) $(ECR_URI):latest
	@echo "==> Verifying architecture"
	docker image inspect $(ECR_URI):amd64 --format 'Architecture: {{.Architecture}}'
	@echo "==> Logging into ECR"
	aws-vault exec $(AWS_PROFILE) -- aws ecr get-login-password --region $(AWS_REGION) | \
		docker login --username AWS --password-stdin $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com
	@echo "==> Pushing to ECR"
	docker push $(ECR_URI):amd64
	docker push $(ECR_URI):latest

.PHONY: docker-clean
docker-clean:
	-docker rmi $(ECR_URI):amd64 $(ECR_URI):latest
	-docker images | grep postgres | awk '{print $$3}' | xargs docker rmi

.PHONY: ecs-register-aurora
ecs-register-aurora:
	@echo "==> Registering Aurora cluster test task definition"
	aws-vault exec $(AWS_PROFILE) -- aws ecs register-task-definition \
		--family $(TASK_FAMILY)-aurora \
		--network-mode awsvpc \
		--requires-compatibilities FARGATE \
		--cpu 256 \
		--memory 512 \
		--execution-role-arn arn:aws:iam::$(AWS_ACCOUNT_ID):role/pattern-a-ecs-task-execution-role \
		--task-role-arn arn:aws:iam::$(AWS_ACCOUNT_ID):role/pattern-a-ecs-task-role \
		--runtime-platform "cpuArchitecture=X86_64,operatingSystemFamily=LINUX" \
		--container-definitions '[{"name":"postgres-client","image":"$(ECR_URI):amd64","command":["/bin/sh","-c","echo \"Testing Aurora cluster connection...\"; PGPASSWORD=password123 psql -h pattern-a-aurora-cluster.cluster-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com -U postgres -d testdb -c \"SELECT current_user, inet_server_addr(), version();\" && echo \"Aurora cluster connection test completed successfully\" || echo \"Aurora cluster connection test failed\""],"essential":true,"logConfiguration":{"logDriver":"awslogs","options":{"awslogs-group":"/ecs/$(TASK_FAMILY)","awslogs-region":"$(AWS_REGION)","awslogs-stream-prefix":"aurora-test"}}}]'

.PHONY: ecs-register-aurora-reader
ecs-register-aurora-reader:
	@echo "==> Registering Aurora reader test task definition"
	aws-vault exec $(AWS_PROFILE) -- aws ecs register-task-definition \
		--family $(TASK_FAMILY)-aurora-reader \
		--network-mode awsvpc \
		--requires-compatibilities FARGATE \
		--cpu 256 \
		--memory 512 \
		--execution-role-arn arn:aws:iam::$(AWS_ACCOUNT_ID):role/pattern-a-ecs-task-execution-role \
		--task-role-arn arn:aws:iam::$(AWS_ACCOUNT_ID):role/pattern-a-ecs-task-role \
		--runtime-platform "cpuArchitecture=X86_64,operatingSystemFamily=LINUX" \
		--container-definitions '[{"name":"postgres-client","image":"$(ECR_URI):amd64","command":["/bin/sh","-c","echo \"Testing Aurora reader endpoint connection...\"; PGPASSWORD=password123 psql -h pattern-a-aurora-cluster.cluster-ro-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com -U postgres -d testdb -c \"SELECT current_user, inet_server_addr(), version();\" && echo \"Aurora reader endpoint connection test completed successfully\" || echo \"Aurora reader endpoint connection test failed\""],"essential":true,"logConfiguration":{"logDriver":"awslogs","options":{"awslogs-group":"/ecs/$(TASK_FAMILY)","awslogs-region":"$(AWS_REGION)","awslogs-stream-prefix":"aurora-reader-test"}}}]'

.PHONY: ecs-register-proxy-writer
ecs-register-proxy-writer:
	@echo "==> Registering RDS Proxy writer test task definition"
	aws-vault exec $(AWS_PROFILE) -- aws ecs register-task-definition \
		--family $(TASK_FAMILY)-proxy-writer \
		--network-mode awsvpc \
		--requires-compatibilities FARGATE \
		--cpu 256 \
		--memory 512 \
		--execution-role-arn arn:aws:iam::$(AWS_ACCOUNT_ID):role/pattern-a-ecs-task-execution-role \
		--task-role-arn arn:aws:iam::$(AWS_ACCOUNT_ID):role/pattern-a-ecs-task-role \
		--runtime-platform "cpuArchitecture=X86_64,operatingSystemFamily=LINUX" \
		--container-definitions '[{"name":"postgres-client","image":"$(ECR_URI):amd64","command":["/bin/sh","-c","echo \"Testing RDS Proxy writer endpoint...\"; PGPASSWORD=password123 psql -h pattern-a-rds-proxy.proxy-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com -U postgres -d testdb -c \"SELECT current_user, inet_server_addr(), version();\" && echo \"RDS Proxy writer connection test completed successfully\" || echo \"RDS Proxy writer connection test failed\""],"essential":true,"logConfiguration":{"logDriver":"awslogs","options":{"awslogs-group":"/ecs/$(TASK_FAMILY)","awslogs-region":"$(AWS_REGION)","awslogs-stream-prefix":"proxy-writer-test"}}}]'

.PHONY: ecs-register-proxy-reader
ecs-register-proxy-reader:
	@echo "==> Registering RDS Proxy reader test task definition"
	aws-vault exec $(AWS_PROFILE) -- aws ecs register-task-definition \
		--family $(TASK_FAMILY)-proxy-reader \
		--network-mode awsvpc \
		--requires-compatibilities FARGATE \
		--cpu 256 \
		--memory 512 \
		--execution-role-arn arn:aws:iam::$(AWS_ACCOUNT_ID):role/pattern-a-ecs-task-execution-role \
		--task-role-arn arn:aws:iam::$(AWS_ACCOUNT_ID):role/pattern-a-ecs-task-role \
		--runtime-platform "cpuArchitecture=X86_64,operatingSystemFamily=LINUX" \
		--container-definitions '[{"name":"postgres-client","image":"$(ECR_URI):amd64","command":["/bin/sh","-c","echo \"Testing RDS Proxy reader endpoint...\"; PGPASSWORD=password123 psql -h pattern-a-rds-proxy-reader.endpoint.proxy-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com -U postgres -d testdb -c \"SELECT current_user, inet_server_addr(), version();\" && echo \"RDS Proxy reader connection test completed successfully\" || echo \"RDS Proxy reader connection test failed\""],"essential":true,"logConfiguration":{"logDriver":"awslogs","options":{"awslogs-group":"/ecs/$(TASK_FAMILY)","awslogs-region":"$(AWS_REGION)","awslogs-stream-prefix":"proxy-reader-test"}}}]'

.PHONY: ecs-register
ecs-register: ecs-register-aurora ecs-register-aurora-reader ecs-register-proxy-writer ecs-register-proxy-reader

.PHONY: ecs-stop
ecs-stop:
	@echo "==> Stopping all running tasks"
	$(eval TASK_ARNS := $(shell aws-vault exec $(AWS_PROFILE) -- aws ecs list-tasks --cluster $(ECS_CLUSTER) --desired-status RUNNING --query 'taskArns[]' --output text))
	@if [ -n "$(TASK_ARNS)" ]; then \
		for task in $(TASK_ARNS); do \
			echo "==> Stopping task: $$task"; \
			aws-vault exec $(AWS_PROFILE) -- aws ecs stop-task --cluster $(ECS_CLUSTER) --task $$task; \
		done; \
	else \
		echo "==> No running tasks found"; \
	fi

.PHONY: ecs-logs
ecs-logs:
	@echo "==> Tailing ECS logs"
	aws-vault exec $(AWS_PROFILE) -- aws logs tail /ecs/$(TASK_FAMILY) --follow

.PHONY: test-aurora
test-aurora:
	@echo "==> Running Aurora cluster connection test task"
	$(eval SUBNET_IDS := $(shell aws-vault exec $(AWS_PROFILE) -- aws ec2 describe-subnets --filters "Name=tag:Name,Values=pattern-a-private-*" --query 'Subnets[].SubnetId' --output text | tr '\t' ','))
	$(eval SG_ID := $(shell aws-vault exec $(AWS_PROFILE) -- aws ec2 describe-security-groups --filters "Name=tag:Name,Values=pattern-a-ecs-tasks-sg" --query 'SecurityGroups[0].GroupId' --output text))
	$(eval TASK_ARN := $(shell aws-vault exec $(AWS_PROFILE) -- aws ecs run-task \
		--cluster $(ECS_CLUSTER) \
		--task-definition $(TASK_FAMILY)-aurora \
		--launch-type FARGATE \
		--network-configuration "awsvpcConfiguration={subnets=[$(SUBNET_IDS)],securityGroups=[$(SG_ID)],assignPublicIp=DISABLED}" \
		--query 'tasks[0].taskArn' --output text))
	@echo "==> Task started: $(TASK_ARN)"
	@echo "==> Waiting for task to complete..."
	@aws-vault exec $(AWS_PROFILE) -- aws ecs wait tasks-stopped --cluster $(ECS_CLUSTER) --tasks $(TASK_ARN)
	@echo "==> Showing logs:"
	@aws-vault exec $(AWS_PROFILE) -- aws logs tail /ecs/$(TASK_FAMILY) --filter-pattern aurora-test --since 5m --format short

.PHONY: test-aurora-reader
test-aurora-reader:
	@echo "==> Running Aurora reader endpoint connection test task"
	$(eval SUBNET_IDS := $(shell aws-vault exec $(AWS_PROFILE) -- aws ec2 describe-subnets --filters "Name=tag:Name,Values=pattern-a-private-*" --query 'Subnets[].SubnetId' --output text | tr '\t' ','))
	$(eval SG_ID := $(shell aws-vault exec $(AWS_PROFILE) -- aws ec2 describe-security-groups --filters "Name=tag:Name,Values=pattern-a-ecs-tasks-sg" --query 'SecurityGroups[0].GroupId' --output text))
	$(eval TASK_ARN := $(shell aws-vault exec $(AWS_PROFILE) -- aws ecs run-task \
		--cluster $(ECS_CLUSTER) \
		--task-definition $(TASK_FAMILY)-aurora-reader \
		--launch-type FARGATE \
		--network-configuration "awsvpcConfiguration={subnets=[$(SUBNET_IDS)],securityGroups=[$(SG_ID)],assignPublicIp=DISABLED}" \
		--query 'tasks[0].taskArn' --output text))
	@echo "==> Task started: $(TASK_ARN)"
	@echo "==> Waiting for task to complete..."
	@aws-vault exec $(AWS_PROFILE) -- aws ecs wait tasks-stopped --cluster $(ECS_CLUSTER) --tasks $(TASK_ARN)
	@echo "==> Showing logs:"
	@aws-vault exec $(AWS_PROFILE) -- aws logs tail /ecs/$(TASK_FAMILY) --filter-pattern aurora-reader-test --since 5m --format short

.PHONY: test-proxy-writer
test-proxy-writer:
	@echo "==> Running RDS Proxy writer connection test task"
	$(eval SUBNET_IDS := $(shell aws-vault exec $(AWS_PROFILE) -- aws ec2 describe-subnets --filters "Name=tag:Name,Values=pattern-a-private-*" --query 'Subnets[].SubnetId' --output text | tr '\t' ','))
	$(eval SG_ID := $(shell aws-vault exec $(AWS_PROFILE) -- aws ec2 describe-security-groups --filters "Name=tag:Name,Values=pattern-a-ecs-tasks-sg" --query 'SecurityGroups[0].GroupId' --output text))
	$(eval TASK_ARN := $(shell aws-vault exec $(AWS_PROFILE) -- aws ecs run-task \
		--cluster $(ECS_CLUSTER) \
		--task-definition $(TASK_FAMILY)-proxy-writer \
		--launch-type FARGATE \
		--network-configuration "awsvpcConfiguration={subnets=[$(SUBNET_IDS)],securityGroups=[$(SG_ID)],assignPublicIp=DISABLED}" \
		--query 'tasks[0].taskArn' --output text))
	@echo "==> Task started: $(TASK_ARN)"
	@echo "==> Waiting for task to complete..."
	@aws-vault exec $(AWS_PROFILE) -- aws ecs wait tasks-stopped --cluster $(ECS_CLUSTER) --tasks $(TASK_ARN)
	@echo "==> Showing logs:"
	@aws-vault exec $(AWS_PROFILE) -- aws logs tail /ecs/$(TASK_FAMILY) --filter-pattern proxy-writer-test --since 5m --format short

.PHONY: test-proxy-reader
test-proxy-reader:
	@echo "==> Running RDS Proxy reader connection test task"
	$(eval SUBNET_IDS := $(shell aws-vault exec $(AWS_PROFILE) -- aws ec2 describe-subnets --filters "Name=tag:Name,Values=pattern-a-private-*" --query 'Subnets[].SubnetId' --output text | tr '\t' ','))
	$(eval SG_ID := $(shell aws-vault exec $(AWS_PROFILE) -- aws ec2 describe-security-groups --filters "Name=tag:Name,Values=pattern-a-ecs-tasks-sg" --query 'SecurityGroups[0].GroupId' --output text))
	$(eval TASK_ARN := $(shell aws-vault exec $(AWS_PROFILE) -- aws ecs run-task \
		--cluster $(ECS_CLUSTER) \
		--task-definition $(TASK_FAMILY)-proxy-reader \
		--launch-type FARGATE \
		--network-configuration "awsvpcConfiguration={subnets=[$(SUBNET_IDS)],securityGroups=[$(SG_ID)],assignPublicIp=DISABLED}" \
		--query 'tasks[0].taskArn' --output text))
	@echo "==> Task started: $(TASK_ARN)"
	@echo "==> Waiting for task to complete..."
	@aws-vault exec $(AWS_PROFILE) -- aws ecs wait tasks-stopped --cluster $(ECS_CLUSTER) --tasks $(TASK_ARN)
	@echo "==> Showing logs:"
	@aws-vault exec $(AWS_PROFILE) -- aws logs tail /ecs/$(TASK_FAMILY) --filter-pattern proxy-reader-test --since 5m --format short

.PHONY: test-all
test-all: test-aurora test-aurora-reader test-proxy-writer test-proxy-reader
