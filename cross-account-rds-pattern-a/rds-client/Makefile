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
	@echo "  docker-build    - Build and push amd64 postgres image to ECR"
	@echo "  docker-clean    - Remove local docker images"
	@echo "  ecs-register    - Register ECS task definition"
	@echo "  ecs-run         - Run ECS task"
	@echo "  ecs-stop        - Stop all running tasks"
	@echo "  ecs-logs        - Tail ECS task logs"
	@echo "  test-aurora     - Test Aurora cluster connection"
	@echo "  test-proxy-writer - Test RDS Proxy writer endpoint"
	@echo "  test-proxy-reader - Test RDS Proxy reader endpoint"
	@echo "  test-all        - Run all connection tests"

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

.PHONY: ecs-register
ecs-register:
	@echo "==> Registering ECS task definition"
	aws-vault exec $(AWS_PROFILE) -- aws ecs register-task-definition \
		--family $(TASK_FAMILY) \
		--network-mode awsvpc \
		--requires-compatibilities FARGATE \
		--cpu 256 \
		--memory 512 \
		--execution-role-arn arn:aws:iam::$(AWS_ACCOUNT_ID):role/pattern-a-ecs-task-execution-role \
		--task-role-arn arn:aws:iam::$(AWS_ACCOUNT_ID):role/pattern-a-ecs-task-role \
		--runtime-platform "cpuArchitecture=X86_64,operatingSystemFamily=LINUX" \
		--container-definitions '[{"name":"postgres-client","image":"$(ECR_URI):amd64","command":["/bin/sh","-c","while true; do sleep 3600; done"],"essential":true,"logConfiguration":{"logDriver":"awslogs","options":{"awslogs-group":"/ecs/$(TASK_FAMILY)","awslogs-region":"$(AWS_REGION)","awslogs-stream-prefix":"postgres-test"}},"linuxParameters":{"initProcessEnabled":true}}]'

.PHONY: ecs-run
ecs-run:
	@echo "==> Getting subnet and security group IDs"
	$(eval SUBNET_IDS := $(shell aws-vault exec $(AWS_PROFILE) -- aws ec2 describe-subnets --filters "Name=tag:Name,Values=pattern-a-private-*" --query 'Subnets[].SubnetId' --output text | tr '\t' ','))
	$(eval SG_ID := $(shell aws-vault exec $(AWS_PROFILE) -- aws ec2 describe-security-groups --filters "Name=tag:Name,Values=pattern-a-ecs-tasks-sg" --query 'SecurityGroups[0].GroupId' --output text))
	@echo "==> Running ECS task"
	$(eval TASK_ARN := $(shell aws-vault exec $(AWS_PROFILE) -- aws ecs run-task \
		--cluster $(ECS_CLUSTER) \
		--task-definition $(TASK_FAMILY) \
		--launch-type FARGATE \
		--enable-execute-command \
		--network-configuration "awsvpcConfiguration={subnets=[$(SUBNET_IDS)],securityGroups=[$(SG_ID)],assignPublicIp=DISABLED}" \
		--query 'tasks[0].taskArn' --output text))
	@echo "==> Task started: $(TASK_ARN)"
	@echo "==> Waiting for task to reach RUNNING state..."
	@sleep 20
	@aws-vault exec $(AWS_PROFILE) -- aws ecs describe-tasks --cluster $(ECS_CLUSTER) --tasks $(TASK_ARN) --query 'tasks[0].lastStatus' --output text

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

.PHONY: get-task-id
get-task-id:
	@aws-vault exec $(AWS_PROFILE) -- aws ecs list-tasks --cluster $(ECS_CLUSTER) --desired-status RUNNING --query 'taskArns[0]' --output text | awk -F'/' '{print $$NF}'

.PHONY: test-aurora
test-aurora:
	$(eval TASK_ID := $(shell make -s get-task-id))
	@echo "==> Testing Aurora cluster connection (Task: $(TASK_ID))"
	aws-vault exec $(AWS_PROFILE) -- aws ecs execute-command \
		--cluster $(ECS_CLUSTER) \
		--task $(TASK_ID) \
		--container postgres-client \
		--interactive \
		--command 'PGPASSWORD=password123 psql -h pattern-a-aurora-cluster.cluster-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com -U postgres -d testdb -c "SELECT current_user, inet_server_addr(), version();"'

.PHONY: test-proxy-writer
test-proxy-writer:
	$(eval TASK_ID := $(shell make -s get-task-id))
	@echo "==> Testing RDS Proxy writer endpoint (Task: $(TASK_ID))"
	aws-vault exec $(AWS_PROFILE) -- aws ecs execute-command \
		--cluster $(ECS_CLUSTER) \
		--task $(TASK_ID) \
		--container postgres-client \
		--interactive \
		--command 'PGPASSWORD=password123 psql -h pattern-a-rds-proxy.proxy-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com -U postgres -d testdb -c "SELECT current_user, inet_server_addr(), version();"'

.PHONY: test-proxy-reader
test-proxy-reader:
	$(eval TASK_ID := $(shell make -s get-task-id))
	@echo "==> Testing RDS Proxy reader endpoint (Task: $(TASK_ID))"
	aws-vault exec $(AWS_PROFILE) -- aws ecs execute-command \
		--cluster $(ECS_CLUSTER) \
		--task $(TASK_ID) \
		--container postgres-client \
		--interactive \
		--command 'PGPASSWORD=password123 psql -h pattern-a-rds-proxy-reader.endpoint.proxy-cpo0q8m8sxzx.ap-northeast-1.rds.amazonaws.com -U postgres -d testdb -c "SELECT current_user, inet_server_addr(), version();"'

.PHONY: test-all
test-all: test-aurora test-proxy-writer test-proxy-reader

.PHONY: setup
setup: docker-build ecs-register ecs-run
	@echo "==> Setup complete! Waiting 30 seconds for ECS Exec to be ready..."
	@sleep 30
	@echo "==> Ready to run tests with: make test-all"
