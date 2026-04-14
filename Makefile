SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

REGISTRY_HOST ?= localhost:5001
IMAGE_PREFIX ?= securerag-hub
IMAGE_TAG ?= dev
SOURCE_IMAGE_TAG ?= $(IMAGE_TAG)
TARGET_IMAGE_TAG ?= release-local
KUSTOMIZE_OVERLAY ?= infra/k8s/overlays/dev
REPORT_DIR ?= artifacts/release
SBOM_DIR ?= artifacts/sbom
DIGEST_RECORD_FILE ?= $(REPORT_DIR)/promotion-digests.txt
OFFICIAL_SCENARIO ?= demo
SUPPORT_PACK_ROOT ?= artifacts/support-pack

.PHONY: help lint test laravel-test verify promote promote-digest deploy validate demo campaign final-campaign release-evidence release-attestation supply-chain-evidence supply-chain-execute observability-snapshot portal-service-proof global-project-status close-missing-phases jenkins-webhook-proof jenkins-ci-push-proof cluster-security-proof refresh-cluster-security-proof devsecops-final-proof devsecops-readiness final-proof final-summary support-pack kyverno-install kyverno-enforce metrics-install clean

help: ## Show available targets
	@awk 'BEGIN {FS = ":.*## "; print "Available targets:"} /^[a-zA-Z0-9_.-]+:.*## / {printf "  %-12s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

lint: ## Validate shell scripts, Jenkins config, and Kustomize renders
	@bash -n scripts/ci/*.sh scripts/cd/*.sh scripts/deploy/*.sh scripts/release/*.sh scripts/secrets/*.sh scripts/validate/*.sh scripts/jenkins/*.sh
	@docker compose -f infra/jenkins/docker-compose.yml config >/dev/null
	@kubectl kustomize infra/k8s/overlays/dev >/dev/null
	@kubectl kustomize infra/k8s/overlays/demo >/dev/null
	@kubectl kustomize infra/k8s/policies/kyverno >/dev/null

test: ## Run automated tests and coverage collection
	@bash scripts/ci/run-tests.sh
	@bash scripts/ci/collect-coverage.sh

laravel-test: ## Run Blade portal and Laravel business microservice tests
	@for app in platform/portal-web services-laravel/auth-users-service services-laravel/chatbot-manager-service services-laravel/conversation-service services-laravel/audit-security-service; do \
		echo "[INFO] Testing $$app"; \
		(cd "$$app" && php artisan test); \
	done

verify: ## Verify image signatures for IMAGE_TAG
	@REGISTRY_HOST=$(REGISTRY_HOST) IMAGE_PREFIX=$(IMAGE_PREFIX) IMAGE_TAG=$(IMAGE_TAG) REPORT_DIR=$(REPORT_DIR) \
		bash scripts/release/verify-signatures.sh

promote: ## Promote already verified images from SOURCE_IMAGE_TAG to TARGET_IMAGE_TAG
	@REGISTRY_HOST=$(REGISTRY_HOST) IMAGE_PREFIX=$(IMAGE_PREFIX) SOURCE_IMAGE_TAG=$(SOURCE_IMAGE_TAG) TARGET_IMAGE_TAG=$(TARGET_IMAGE_TAG) REPORT_DIR=$(REPORT_DIR) \
		bash scripts/release/promote-verified-images.sh

promote-digest: ## Promote already verified images by digest and record per-service digests
	@REGISTRY_HOST=$(REGISTRY_HOST) IMAGE_PREFIX=$(IMAGE_PREFIX) SOURCE_IMAGE_TAG=$(SOURCE_IMAGE_TAG) TARGET_IMAGE_TAG=$(TARGET_IMAGE_TAG) REPORT_DIR=$(REPORT_DIR) DIGEST_RECORD_FILE=$(DIGEST_RECORD_FILE) \
		bash scripts/release/promote-by-digest.sh

deploy: ## Verify, then deploy TARGET_IMAGE_TAG (or IMAGE_TAG if set explicitly) to kind
	@REGISTRY_HOST=$(REGISTRY_HOST) IMAGE_PREFIX=$(IMAGE_PREFIX) IMAGE_TAG=$(IMAGE_TAG) REPORT_DIR=$(REPORT_DIR) DIGEST_RECORD_FILE=$(DIGEST_RECORD_FILE) KUSTOMIZE_OVERLAY=$(KUSTOMIZE_OVERLAY) \
		bash scripts/deploy/verify-and-deploy-kind.sh

validate: ## Run post-deployment validation and collect runtime evidence
	@bash scripts/validate/smoke-tests.sh
	@bash scripts/validate/security-smoke.sh
	@bash scripts/validate/e2e-functional-flow.sh
	@bash scripts/validate/rag-smoke.sh
	@bash scripts/validate/security-adversarial-advanced.sh
	@bash scripts/validate/generate-validation-report.sh
	@bash scripts/validate/collect-runtime-evidence.sh

demo: ## Deploy the demo overlay with the Ollama mock fallback
	@REGISTRY_HOST=$(REGISTRY_HOST) IMAGE_PREFIX=$(IMAGE_PREFIX) IMAGE_TAG=$(IMAGE_TAG) KUSTOMIZE_OVERLAY=infra/k8s/overlays/demo \
		bash scripts/deploy/deploy-kind.sh

campaign: ## Run the full reference campaign verify -> promote -> deploy -> validate
	@REGISTRY_HOST=$(REGISTRY_HOST) IMAGE_PREFIX=$(IMAGE_PREFIX) SOURCE_IMAGE_TAG=$(SOURCE_IMAGE_TAG) TARGET_IMAGE_TAG=$(TARGET_IMAGE_TAG) KUSTOMIZE_OVERLAY=$(KUSTOMIZE_OVERLAY) REPORT_DIR=$(REPORT_DIR) DIGEST_RECORD_FILE=$(DIGEST_RECORD_FILE) \
		bash scripts/validate/run-reference-campaign.sh

final-campaign: ## Run the official final campaign wrapper with support-pack generation
	@REGISTRY_HOST=$(REGISTRY_HOST) IMAGE_PREFIX=$(IMAGE_PREFIX) SOURCE_IMAGE_TAG=$(SOURCE_IMAGE_TAG) TARGET_IMAGE_TAG=$(TARGET_IMAGE_TAG) REPORT_DIR=$(REPORT_DIR) DIGEST_RECORD_FILE=$(DIGEST_RECORD_FILE) OFFICIAL_SCENARIO=$(OFFICIAL_SCENARIO) SUPPORT_PACK_ROOT=$(SUPPORT_PACK_ROOT) \
		bash scripts/cd/run-final-campaign.sh

release-evidence: ## Generate a consolidated release evidence document
	@REGISTRY_HOST=$(REGISTRY_HOST) IMAGE_PREFIX=$(IMAGE_PREFIX) SOURCE_IMAGE_TAG=$(SOURCE_IMAGE_TAG) TARGET_IMAGE_TAG=$(TARGET_IMAGE_TAG) REPORT_DIR=$(REPORT_DIR) SBOM_DIR=$(SBOM_DIR) DIGEST_RECORD_FILE=$(DIGEST_RECORD_FILE) \
		bash scripts/release/record-release-evidence.sh

release-attestation: ## Generate a local release attestation from available evidence
	@REGISTRY_HOST=$(REGISTRY_HOST) IMAGE_PREFIX=$(IMAGE_PREFIX) SOURCE_IMAGE_TAG=$(SOURCE_IMAGE_TAG) TARGET_IMAGE_TAG=$(TARGET_IMAGE_TAG) REPORT_DIR=$(REPORT_DIR) SBOM_DIR=$(SBOM_DIR) DIGEST_RECORD_FILE=$(DIGEST_RECORD_FILE) \
		bash scripts/release/generate-release-attestation.sh

supply-chain-evidence: ## Consolidate SBOM, signature, verification and promotion evidence
	@REPORT_DIR=$(REPORT_DIR) SBOM_DIR=$(SBOM_DIR) bash scripts/release/collect-supply-chain-evidence.sh

supply-chain-execute: ## Sign, verify, promote by digest, generate SBOMs and record evidence
	@REGISTRY_HOST=$(REGISTRY_HOST) IMAGE_PREFIX=$(IMAGE_PREFIX) SOURCE_IMAGE_TAG=$(SOURCE_IMAGE_TAG) TARGET_IMAGE_TAG=$(TARGET_IMAGE_TAG) REPORT_DIR=$(REPORT_DIR) SBOM_DIR=$(SBOM_DIR) DIGEST_RECORD_FILE=$(DIGEST_RECORD_FILE) \
		bash scripts/release/run-supply-chain-execute.sh

observability-snapshot: ## Generate a read-only Kubernetes, Kyverno, HPA and Jenkins observability snapshot
	@bash scripts/validate/generate-observability-snapshot.sh

portal-service-proof: ## Validate Blade portal connectivity to Laravel business services
	@bash scripts/validate/validate-portal-service-connectivity.sh

global-project-status: ## Generate a factual global project status report
	@bash scripts/validate/generate-global-project-status.sh

close-missing-phases: ## Close remaining environment-dependent phases with safe defaults
	@bash scripts/validate/run-missing-phases-closure.sh

jenkins-webhook-proof: ## Validate Jenkins GitHub webhook reachability and CI trigger readiness
	@bash scripts/jenkins/validate-github-webhook.sh

jenkins-ci-push-proof: ## Verify Jenkins consumed the latest pushed Git commit
	@bash scripts/jenkins/verify-ci-push-trigger.sh

cluster-security-proof: ## Collect metrics-server, HPA and Kyverno runtime evidence
	@bash scripts/validate/validate-cluster-security-addons.sh

refresh-cluster-security-proof: ## Install metrics-server/Kyverno (Audit) and archive fresh runtime security proof
	@bash scripts/validate/refresh-cluster-security-proof.sh

devsecops-final-proof: ## Run the non-destructive final DevSecOps proof orchestrator
	@bash scripts/validate/run-devsecops-final-proof.sh

devsecops-readiness: ## Generate a factual DevSecOps readiness report for soutenance
	@bash scripts/validate/generate-devsecops-readiness-report.sh

final-proof: ## Run the final non-destructive soutenance proof checks
	@bash scripts/validate/final-proof-check.sh

final-summary: ## Generate the final soutenance validation summary
	@bash scripts/validate/generate-final-validation-summary.sh

support-pack: ## Build a support pack from current release, validation and Jenkins artefacts
	@SUPPORT_PACK_ROOT=$(SUPPORT_PACK_ROOT) bash scripts/validate/build-support-pack.sh

kyverno-install: ## Install Kyverno and apply SecureRAG policies in Audit mode
	@bash scripts/deploy/install-kyverno.sh

kyverno-enforce: ## Install Kyverno and apply the Enforce overlay for Cosign verification
	@KYVERNO_POLICY_MODE=enforce bash scripts/deploy/install-kyverno.sh

metrics-install: ## Install metrics-server for local HPA metrics
	@bash scripts/deploy/install-metrics-server.sh

clean: ## Remove generated local artifacts
	@rm -rf .coverage-artifacts artifacts/release artifacts/sbom artifacts/validation artifacts/jenkins artifacts/final artifacts/support-pack security/reports
