# Environment Configuration
ENV ?= dev
STACK_NAME ?= private-ec2-stack
KEY_PAIR ?= my-key-pair
INSTANCE_TYPE ?= t3.micro

# Get current IPv4 address only (multiple fallback methods)
CURRENT_IP := $(shell curl -s -4 --connect-timeout 5 --max-time 10 ifconfig.me 2>/dev/null || curl -s -4 --connect-timeout 5 --max-time 10 ipv4.icanhazip.com 2>/dev/null || curl -s -4 --connect-timeout 5 --max-time 10 checkip.amazonaws.com 2>/dev/null || echo "127.0.0.1")

# Default target
.PHONY: help
help:
	@echo "PoC CloudFormation Deployment"
	@echo ""
	@echo "Available targets:"
	@echo "  create-env    - Create environment configuration"
	@echo "  validate      - Validate CloudFormation template"
	@echo "  deploy        - Deploy CloudFormation stack"
	@echo "  test          - Test connection to deployed resources"
	@echo "  destroy       - Destroy CloudFormation stack"
	@echo ""
	@echo "Current IPv4: $(CURRENT_IP)"
	@echo "Environment: $(ENV)"

# Create environment configuration
.PHONY: create-env
create-env:
	@echo "Using IPv4 address: $(CURRENT_IP)"
	./script/create-env.sh $(ENV) $(STACK_NAME) $(KEY_PAIR) $(CURRENT_IP)/32 $(INSTANCE_TYPE)

# Validate CloudFormation template
.PHONY: validate
validate:
	./script/deploy.sh --env $(ENV) --validate-only

# Deploy CloudFormation stack
.PHONY: deploy
deploy:
	./script/deploy.sh --env $(ENV) --deploy

# Test connection
.PHONY: test
test:
	./script/connection-test.sh --env $(ENV) --full-test

# Destroy CloudFormation stack
.PHONY: destroy
destroy:
	./script/deploy.sh --env $(ENV) --destroy

# Manual stack deletion
.PHONY: delete-stack
delete-stack:
	aws cloudformation delete-stack \
		--stack-name $(STACK_NAME) \
		--region ap-northeast-1