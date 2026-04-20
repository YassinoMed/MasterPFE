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
REQUIRE_DIGEST_DEPLOY ?= false
DEPLOY_EVIDENCE_FILE ?= $(REPORT_DIR)/no-rebuild-deploy-summary.md
OFFICIAL_SCENARIO ?= demo
SUPPORT_PACK_ROOT ?= artifacts/support-pack

.PHONY: help lint test laravel-test sonar-analysis kyverno-policy-check image-scan sbom-attest sbom-validate verify promote promote-digest deploy validate demo production-cluster production-cleanup-plan production-cleanup production-cluster-clean-proof production-ha production-runtime-evidence production-proof-full ha-chaos-lite hpa-runtime-proof refresh-hpa-runtime-proof production-data-resilience data-resilience-proof production-dockerfiles image-size-evidence secrets-management production-db-secret data-backup data-restore production-readiness-campaign campaign final-campaign release-evidence release-attestation release-provenance release-proof-strict supply-chain-evidence supply-chain-execute observability-snapshot portal-service-proof global-project-status final-source-of-truth security-posture k8s-resource-guards close-missing-phases jenkins-webhook-proof jenkins-ci-push-proof cluster-security-proof kyverno-runtime-proof kyverno-enforce-readiness refresh-cluster-security-proof devsecops-final-proof devsecops-readiness final-proof final-summary support-pack kyverno-install kyverno-enforce metrics-install clean

help: ## Show available targets
	@awk 'BEGIN {FS = ":.*## "; print "Available targets:"} /^[a-zA-Z0-9_.-]+:.*## / {printf "  %-12s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

lint: ## Validate shell scripts, Jenkins config, Kustomize renders and security scopes
	@bash -n scripts/ci/*.sh scripts/cd/*.sh scripts/deploy/*.sh scripts/release/*.sh scripts/release/lib/*.sh scripts/secrets/*.sh scripts/validate/*.sh scripts/validate/lib/*.sh scripts/jenkins/*.sh
	@docker compose -f infra/jenkins/docker-compose.yml config >/dev/null
	@kubectl kustomize infra/k8s/overlays/dev >/dev/null
	@kubectl kustomize infra/k8s/overlays/demo >/dev/null
	@kubectl kustomize infra/k8s/overlays/production >/dev/null
	@kubectl kustomize infra/k8s/overlays/production-external-db >/dev/null
	@kubectl kustomize infra/k8s/policies/kyverno >/dev/null
	@kubectl kustomize infra/k8s/policies/kyverno-enforce >/dev/null
	@bash scripts/validate/validate-k8s-cleartext-scope.sh >/dev/null
	@bash scripts/validate/validate-k8s-resource-guards.sh >/dev/null
	@bash scripts/validate/validate-k8s-ultra-hardening.sh >/dev/null
	@bash scripts/validate/validate-production-ha.sh >/dev/null
	@STATIC_ONLY=true bash scripts/validate/validate-production-cluster-clean.sh >/dev/null
	@bash scripts/validate/validate-production-data-resilience.sh >/dev/null
	@bash scripts/validate/validate-production-dockerfiles.sh >/dev/null
	@bash scripts/secrets/validate-secrets-management.sh >/dev/null
	@bash scripts/release/validate-sbom-cyclonedx.sh >/dev/null
	@bash scripts/ci/validate-sonar-cpd-scope.sh >/dev/null

test: ## Run automated tests and coverage collection
	@bash scripts/ci/run-tests.sh
	@bash scripts/ci/collect-coverage.sh

laravel-test: ## Run Blade portal and Laravel business microservice tests
	@for app in platform/portal-web services-laravel/auth-users-service services-laravel/chatbot-manager-service services-laravel/conversation-service services-laravel/audit-security-service; do \
		echo "[INFO] Testing $$app"; \
		(cd "$$app" && php artisan test); \
	done

sonar-analysis: ## Run Sonar analysis and quality gate when SONAR_HOST_URL/SONAR_TOKEN are configured
	@bash scripts/ci/run-sonar-analysis.sh

kyverno-policy-check: ## Validate Kyverno policies against rendered Kubernetes resources without requiring a cluster
	@bash scripts/ci/validate-kyverno-policies.sh

image-scan: ## Scan official release candidate images with Trivy before signing
	@REGISTRY_HOST=$(REGISTRY_HOST) IMAGE_PREFIX=$(IMAGE_PREFIX) IMAGE_TAG=$(IMAGE_TAG) REPORT_DIR=$(REPORT_DIR) \
		bash scripts/release/scan-images.sh

sbom-attest: ## Attach generated CycloneDX SBOMs to images using Cosign attest
	@REGISTRY_HOST=$(REGISTRY_HOST) IMAGE_PREFIX=$(IMAGE_PREFIX) IMAGE_TAG=$(TARGET_IMAGE_TAG) REPORT_DIR=$(REPORT_DIR) SBOM_DIR=$(SBOM_DIR) \
		bash scripts/release/attest-sboms.sh

sbom-validate: ## Validate generated SBOM files are CycloneDX JSON
	@REPORT_DIR=$(REPORT_DIR) SBOM_DIR=$(SBOM_DIR) bash scripts/release/validate-sbom-cyclonedx.sh

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
	@REGISTRY_HOST=$(REGISTRY_HOST) IMAGE_PREFIX=$(IMAGE_PREFIX) IMAGE_TAG=$(IMAGE_TAG) REPORT_DIR=$(REPORT_DIR) IMAGE_DIGEST_FILE=$(DIGEST_RECORD_FILE) KUSTOMIZE_OVERLAY=$(KUSTOMIZE_OVERLAY) REQUIRE_DIGEST_DEPLOY=$(REQUIRE_DIGEST_DEPLOY) DEPLOY_EVIDENCE_FILE=$(DEPLOY_EVIDENCE_FILE) \
		bash scripts/deploy/verify-and-deploy-kind.sh

validate: ## Run post-deployment validation and collect runtime evidence
	@bash scripts/validate/smoke-tests.sh
	@bash scripts/validate/security-smoke.sh
	@bash scripts/validate/e2e-functional-flow.sh
	@bash scripts/validate/security-adversarial-advanced.sh
	@bash scripts/validate/generate-validation-report.sh
	@bash scripts/validate/collect-runtime-evidence.sh

demo: ## Deploy the Laravel demo overlay
	@REGISTRY_HOST=$(REGISTRY_HOST) IMAGE_PREFIX=$(IMAGE_PREFIX) IMAGE_TAG=$(IMAGE_TAG) KUSTOMIZE_OVERLAY=infra/k8s/overlays/demo \
		bash scripts/deploy/deploy-kind.sh

production-cluster: ## Create a guarded production-like kind cluster
	@bash scripts/deploy/recreate-production-kind.sh

production-cleanup-plan: ## Show legacy runtime objects without deleting anything
	@bash scripts/deploy/cleanup-nonproduction-workloads.sh

production-cleanup: ## Delete legacy runtime objects only when CONFIRM_CLEANUP=YES is provided
	@CONFIRM_CLEANUP=$(CONFIRM_CLEANUP) DELETE_STATEFUL_LEGACY=$(DELETE_STATEFUL_LEGACY) bash scripts/deploy/cleanup-nonproduction-workloads.sh

production-cluster-clean-proof: ## Validate production-only runtime scope and official portal exposure
	@bash scripts/validate/validate-production-cluster-clean.sh

production-ha: ## Validate the production overlay HA controls without mutating the cluster
	@bash scripts/validate/validate-production-ha.sh

production-runtime-evidence: ## Collect read-only runtime evidence for production HA and HPA
	@bash scripts/validate/collect-production-runtime-evidence.sh

production-proof-full: ## Run the full production proof orchestrator; read-only unless RUN_CLUSTER_MUTATIONS=true
	@bash scripts/validate/run-production-proof-full.sh

ha-chaos-lite: ## Collect HA resilience proof; mutative checks require explicit RUN_* variables
	@bash scripts/validate/validate-ha-chaos-lite.sh

hpa-runtime-proof: ## Collect a read-only strict HPA and metrics-server runtime report
	@bash scripts/validate/validate-hpa-runtime.sh

refresh-hpa-runtime-proof: ## Install/repair metrics-server and collect strict HPA runtime proof
	@bash scripts/validate/refresh-hpa-runtime-proof.sh

production-data-resilience: ## Validate production data resilience readiness
	@bash scripts/validate/validate-production-data-resilience.sh

data-resilience-proof: ## Run DB external secret, backup, restore and data resilience proof when PostgreSQL env vars exist
	@bash scripts/data/run-data-resilience-proof.sh

production-dockerfiles: ## Validate production Laravel Dockerfiles are hardened and dependency-clean
	@bash scripts/validate/validate-production-dockerfiles.sh

image-size-evidence: ## Collect local Docker image size evidence for official Laravel images
	@REGISTRY_HOST=$(REGISTRY_HOST) IMAGE_PREFIX=$(IMAGE_PREFIX) IMAGE_TAG=$(IMAGE_TAG) bash scripts/validate/collect-image-size-evidence.sh

secrets-management: ## Validate modern secrets management readiness without exposing values
	@bash scripts/secrets/validate-secrets-management.sh

production-db-secret: ## Create/update the production external DB Secret from environment variables
	@bash scripts/secrets/create-production-db-secret.sh

data-backup: ## Create a PostgreSQL backup evidence artifact from external DB env vars
	@bash scripts/data/backup-postgres.sh

data-restore: ## Restore a PostgreSQL backup into an isolated restore database
	@bash scripts/data/restore-postgres.sh

production-readiness-campaign: ## Run the production readiness campaign, read-only by default
	@bash scripts/validate/run-production-readiness-campaign.sh

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

release-provenance: ## Generate a SLSA-style provenance statement from release evidence
	@REPORT_DIR=$(REPORT_DIR) DIGEST_RECORD_FILE=$(DIGEST_RECORD_FILE) bash scripts/release/generate-provenance-statement.sh

release-proof-strict: ## Execute strict supply-chain proof with SBOM validation, attestation and SLSA-style provenance
	@REGISTRY_HOST=$(REGISTRY_HOST) IMAGE_PREFIX=$(IMAGE_PREFIX) SOURCE_IMAGE_TAG=$(SOURCE_IMAGE_TAG) TARGET_IMAGE_TAG=$(TARGET_IMAGE_TAG) REPORT_DIR=$(REPORT_DIR) SBOM_DIR=$(SBOM_DIR) DIGEST_RECORD_FILE=$(DIGEST_RECORD_FILE) \
		bash scripts/release/run-release-proof-strict.sh

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

final-source-of-truth: ## Generate final security, production, release and memory artefact status tables
	@bash scripts/validate/generate-final-source-of-truth.sh

security-posture: ## Generate a factual security posture report
	@bash scripts/validate/generate-security-posture-report.sh

k8s-cleartext-scope: ## Validate that Kubernetes HTTP is restricted to internal scoped demo traffic
	@bash scripts/validate/validate-k8s-cleartext-scope.sh

k8s-resource-guards: ## Validate Kubernetes CPU, memory and ephemeral-storage guards
	@bash scripts/validate/validate-k8s-resource-guards.sh

k8s-ultra-hardening: ## Validate Kubernetes restricted Pod Security, policies, probes, RBAC and exposure
	@bash scripts/validate/validate-k8s-ultra-hardening.sh

close-missing-phases: ## Close remaining environment-dependent phases with safe defaults
	@bash scripts/validate/run-missing-phases-closure.sh

jenkins-webhook-proof: ## Validate Jenkins GitHub webhook reachability and CI trigger readiness
	@bash scripts/jenkins/validate-github-webhook.sh

jenkins-ci-push-proof: ## Verify Jenkins consumed the latest pushed Git commit
	@bash scripts/jenkins/verify-ci-push-trigger.sh

cluster-security-proof: ## Collect metrics-server, HPA and Kyverno runtime evidence
	@bash scripts/validate/validate-cluster-security-addons.sh

kyverno-runtime-proof: ## Collect Kyverno CRD, policy, PolicyReport and Enforce readiness evidence
	@bash scripts/validate/validate-kyverno-runtime.sh

kyverno-enforce-readiness: ## Generate a dedicated Kyverno Enforce readiness decision report
	@bash scripts/validate/validate-kyverno-enforce-readiness.sh

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
