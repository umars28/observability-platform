# Observability Platform — command orchestration
# Every target should be idempotent and safe to re-run.

SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

# ─── Config ─────────────────────────────────────────────────────────────
CLUSTER          ?= local
KIND_CLUSTER     ?= observability
KIND_CONFIG      := scripts/kind-config.yaml
KUBECONFIG_LOCAL := $(HOME)/.kube/kind-$(KIND_CLUSTER)
NAMESPACE        := observability
HELM             := helm
KUBECTL          := kubectl

# Colors
GREEN  := \033[0;32m
YELLOW := \033[1;33m
RESET  := \033[0m

# ─── Help ───────────────────────────────────────────────────────────────
.PHONY: help
help: ## Show this help
	@echo -e "$(GREEN)Observability Platform — Makefile targets$(RESET)"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*?##/ { printf "  $(YELLOW)%-22s$(RESET) %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

# ─── Local dev (kind) ───────────────────────────────────────────────────
.PHONY: local-up
local-up: check-tools ## Spin up kind cluster + MinIO + LGTMP locally
	@echo -e "$(GREEN)▶ Creating kind cluster '$(KIND_CLUSTER)'...$(RESET)"
	@kind get clusters | grep -q "^$(KIND_CLUSTER)$$" || kind create cluster --name $(KIND_CLUSTER) --config $(KIND_CONFIG)
	@kind get kubeconfig --name $(KIND_CLUSTER) > $(KUBECONFIG_LOCAL)
	@$(MAKE) bootstrap CLUSTER=local
	@$(MAKE) platform-up CLUSTER=local

.PHONY: local-down
local-down: ## Tear down local kind cluster
	@echo -e "$(YELLOW)▶ Deleting kind cluster '$(KIND_CLUSTER)'...$(RESET)"
	@kind delete cluster --name $(KIND_CLUSTER) || true
	@rm -f $(KUBECONFIG_LOCAL)

.PHONY: local-demo
local-demo: ## Build demo images, load into kind, deploy apps + load generator
	@echo -e "$(GREEN)▶ Building demo images...$(RESET)"
	@$(MAKE) -C apps/demo-shop-api build
	@$(MAKE) -C apps/demo-blog-web build
	@echo -e "$(GREEN)▶ Loading images into kind cluster...$(RESET)"
	@kind load docker-image demo-shop-api:local demo-blog-web:local --name $(KIND_CLUSTER)
	@echo -e "$(GREEN)▶ Deploying demo apps...$(RESET)"
	@$(KUBECTL) apply -k apps/

.PHONY: local-open
local-open: ## Open Grafana in browser (local)
	@echo -e "$(GREEN)▶ Grafana available at http://localhost:3000$(RESET)"
	@$(KUBECTL) port-forward -n $(NAMESPACE) svc/grafana 3000:80

# ─── Platform lifecycle ─────────────────────────────────────────────────
.PHONY: bootstrap
bootstrap: ## Install cluster prerequisites (ArgoCD, cert-manager, ingress)
	@echo -e "$(GREEN)▶ Bootstrapping cluster '$(CLUSTER)'...$(RESET)"
	@./scripts/bootstrap.sh $(CLUSTER)

.PHONY: platform-up
platform-up: ## Deploy LGTMP components via Helm
	@echo -e "$(GREEN)▶ Deploying platform to '$(CLUSTER)'...$(RESET)"
	@./scripts/platform-up.sh $(CLUSTER)

.PHONY: platform-down
platform-down: ## Uninstall LGTMP components
	@echo -e "$(YELLOW)▶ Removing platform from '$(CLUSTER)'...$(RESET)"
	@$(HELM) uninstall -n $(NAMESPACE) mimir loki tempo pyroscope grafana alloy || true

# ─── Tenant management ──────────────────────────────────────────────────
.PHONY: onboard-tenant
onboard-tenant: ## Onboard a new tenant (usage: make onboard-tenant TENANT=my-project)
	@test -n "$(TENANT)" || (echo "Usage: make onboard-tenant TENANT=<name>" && exit 1)
	@./scripts/onboard-tenant.sh $(TENANT)

# ─── Quality gates ──────────────────────────────────────────────────────
.PHONY: lint
lint: ## Run all linters
	@echo -e "$(GREEN)▶ Linting...$(RESET)"
	@yamllint -c .yamllint.yaml kubernetes/ dashboards/ alerts/ || true
	@$(HELM) lint kubernetes/platform/*/ 2>/dev/null || true
	@cd terraform && terraform fmt -check -recursive || true

.PHONY: security-scan
security-scan: ## Run security scanners (trivy, checkov)
	@echo -e "$(GREEN)▶ Security scan...$(RESET)"
	@trivy config --exit-code 0 kubernetes/ terraform/
	@checkov -d terraform/ --quiet || true

# ─── Utilities ──────────────────────────────────────────────────────────
.PHONY: check-tools
check-tools: ## Verify required CLI tools are installed
	@./scripts/check-tools.sh

.PHONY: version
version: ## Print component versions
	@cat kubernetes/platform/versions.yaml 2>/dev/null || echo "versions.yaml not found"
