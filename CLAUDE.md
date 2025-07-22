# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Structure

This repository contains multiple independent projects focused on different technologies:

### AWS/Terraform Projects
- **Infrastructure-as-Code samples**: Multiple Terraform configurations for AWS services (ECS, Lambda, DynamoDB, EventBridge, etc.)
- **Common pattern**: Each project has its own directory with `.tf` files and sometimes separate `terraform-role/` subdirectories
- **Key directories**: `aws-quota-monitor/`, `datadog-aws-integration/`, `dynamodb-backup/`, `ecs-sample/`, `fargate-with-fluentbit/`, `eventbridge-scheduler/`, `ecr-with-custom-image/`, `workload-identity-with-aws-ecs-tasks/`

### MCP (Model Context Protocol) Projects
- **TypeScript MCP Server**: `mcp-server-quickstart/` - Weather forecast server using the @modelcontextprotocol/sdk
- **Go MCP Server**: `go-mcp-hands-on/` - Simple "hello world" server using github.com/mark3labs/mcp-go

### Other Projects
- **Haskell exercises**: `programming-haskell/` - Various Haskell learning exercises
- **TypeScript/Deno**: `lambda-note-type-system-with-typescript/` - Type system examples with Deno

## Common Development Commands

### MCP Server Quickstart (TypeScript)
```bash
# Build the TypeScript MCP server
cd mcp-server-quickstart
npm run build

# No tests currently configured (exits with error)
npm test
```

### Go MCP Server
```bash
# Run the Go MCP server
cd go-mcp-hands-on
go run main.go

# Build binary
go build -o mcp-server main.go
```

### Terraform Projects
```bash
# Standard Terraform workflow for any project
terraform init
terraform plan
terraform apply
terraform destroy
```

### TypeScript/Deno Projects
```bash
# Format code in lambda-note-type-system-with-typescript/
cd lambda-note-type-system-with-typescript
deno fmt
```

## Architecture Notes

### MCP Servers
- **mcp-server-quickstart**: Implements a weather forecast tool using the National Weather Service API. Uses TypeScript with Node.js modules and builds to `build/` directory.
- **go-mcp-hands-on**: Simple MCP server with a single "hello_world" tool that greets users by name.

### Terraform Structure
- Most projects follow standard Terraform patterns with provider configurations, resource definitions, and state management
- Some projects include separate IAM roles in `terraform-role/` subdirectories
- Projects often target AWS services with some integration with external services (like Datadog)

### Project Independence
Each directory represents a completely independent project with its own dependencies, build processes, and purposes. There are no shared libraries or cross-project dependencies.