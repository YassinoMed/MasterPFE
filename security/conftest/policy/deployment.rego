# File: security/conftest/policy/deployment.rego
# Description: Conftest policies specific to Kubernetes Deployments
# Modified by: DevSecOps Agent — 2026-06-13

package main

import future.keywords.if
import future.keywords.in

# ---------------------------------------------------------------------------
# require_min_replicas (>= 2 for production)
# ---------------------------------------------------------------------------
require_min_replicas contains msg if {
    input.kind == "Deployment"
    count(input.spec.replicas) > 0
    input.spec.replicas < 2
    msg := sprintf("Deployment %v has %v replicas — minimum 2 required for production", [
        input.metadata.name, input.spec.replicas,
    ])
}

require_min_replicas contains msg if {
    input.kind == "Deployment"
    not input.spec.replicas
    msg := sprintf("Deployment %v has no replicas defined — minimum 2 required for production", [
        input.metadata.name,
    ])
}

# ---------------------------------------------------------------------------
# require_pod_anti_affinity
# ---------------------------------------------------------------------------
require_pod_anti_affinity contains msg if {
    input.kind == "Deployment"
    not input.spec.template.spec.affinity.podAntiAffinity
    msg := sprintf("Deployment %v is missing podAntiAffinity — required for high availability", [
        input.metadata.name,
    ])
}

require_pod_anti_affinity contains msg if {
    input.kind == "StatefulSet"
    not input.spec.template.spec.affinity.podAntiAffinity
    msg := sprintf("StatefulSet %v is missing podAntiAffinity — required for high availability", [
        input.metadata.name,
    ])
}

# ---------------------------------------------------------------------------
# deny_run_as_root (deployment-specific)
# ---------------------------------------------------------------------------
deny_run_as_root contains msg if {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    container.securityContext.runAsUser == 0
    msg := sprintf("Deployment %v container %v runs as root (runAsUser=0) — deny by policy", [
        input.metadata.name, container.name,
    ])
}

deny_run_as_root contains msg if {
    input.kind == "Deployment"
    input.spec.template.spec.securityContext.runAsUser == 0
    msg := sprintf("Deployment %v pod securityContext sets runAsUser=0 — deny by policy", [
        input.metadata.name,
    ])
}
