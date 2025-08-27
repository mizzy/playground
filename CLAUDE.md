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

## Code Formatting Guidelines

### Terminal Copy-Paste Compatibility
When writing bash commands and scripts in documentation or procedure files:
- **Remove inline comments**: Do not include comments within command lines that would interfere with terminal execution
- **Replace exit with return**: In script functions or sourced scripts, use `return` instead of `exit` to avoid terminating the shell session
- **Clean command blocks**: Ensure all command blocks can be directly copy-pasted into a terminal without modification
- **AWS credentials**: Include `aws-vault exec` wrapper where appropriate for AWS CLI commands
- **Japanese messages**: Use Japanese for all echo/output messages in command blocks
- **Execution time tracking**: Add START_TIME and END_TIME tracking to each script section with elapsed time output
- **Expected output sections**: Include "期待される出力例" sections after each command block showing what the user should see
- **Checklist sections**: Include "確認項目" sections with checklist items for verification
- **Shellcheck validation**: Validate all shell scripts with `shellcheck` and fix critical errors:
  - Fix SC2086: Always quote variables (e.g., `"$VAR"` instead of `$VAR`)
  - Fix SC2162: Use `read -r` instead of bare `read`
  - Ignore SC2034 (unused variables), SC2148 (missing shebang in snippets), SC2016 (backticks in JQ queries)

Example of terminal-friendly formatting:
```bash
# Good - comment on separate line
START_TIME=$(date +%s)
echo "変数を設定中"
CLUSTER_ID="aurora-cluster"
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
echo "実行時間: ${ELAPSED}秒"

# Bad - inline comment breaks copy-paste
echo "Setting up variables" # This is a comment
```

### Documentation Structure for Procedures
When writing procedure documentation:
- **Add brief descriptions**: Include a brief description before each execution command section explaining what will be done
- **Organize with clear headers**: Use #### 実行コマンド, #### 期待される出力例, #### 確認項目
- **Include expected outputs**: Show realistic output examples including AWS CLI responses
- **Structure checklists by output sections**: Group checklist items by the output they correspond to (e.g., JSON出力, 表, テキスト出力)
- **Add verification checklists**: Provide checklist items for users to verify each step completed successfully
- **Track execution time**: Show typical execution times for each step
- **Use Japanese consistently**: All user-facing messages should be in Japanese
- **Make procedures generic**: Write procedures to handle various configurations (1台, 2台, それ以上) while keeping examples concrete
