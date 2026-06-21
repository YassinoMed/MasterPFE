# File: security/conftest/policy/kubernetes.rego
# Description: OPA Conftest policies for Kubernetes manifests
# Modified by: DevSecOps Agent — 2026-06-13

package main

import future.keywords.in
import future.keywords.if

# ---------------------------------------------------------------------------
# deny_privileged_containers
# ---------------------------------------------------------------------------
deny_privileged_containers contains msg if {
    container := input.spec.containers[_]
    container.securityContext.privileged == true
    msg := sprintf("Container %v in %v/%v is privileged — deny by policy", [
        container.name, input.kind, input.metadata.name,
    ])
}

deny_privileged_containers contains msg if {
    container := input.spec.initContainers[_]
    container.securityContext.privileged == true
    msg := sprintf("Init container %v in %v/%v is privileged — deny by policy", [
        container.name, input.kind, input.metadata.name,
    ])
}

# ---------------------------------------------------------------------------
# deny_latest_tag
# ---------------------------------------------------------------------------
deny_latest_tag contains msg if {
    container := input.spec.containers[_]
    endswith(container.image, ":latest")
    msg := sprintf("Container %v in %v/%v uses latest tag — pin to an explicit version", [
        container.name, input.kind, input.metadata.name,
    ])
}

deny_latest_tag contains msg if {
    container := input.spec.initContainers[_]
    endswith(container.image, ":latest")
    msg := sprintf("Init container %v in %v/%v uses latest tag — pin to an explicit version", [
        container.name, input.kind, input.metadata.name,
    ])
}

deny_latest_tag contains msg if {
    container := input.spec.containers[_]
    not contains(container.image, ":")
    not endswith(container.image, "@sha")
    msg := sprintf("Container %v in %v/%v uses implicit latest tag — pin to an explicit version", [
        container.name, input.kind, input.metadata.name,
    ])
}

# ---------------------------------------------------------------------------
# require_readiness_probe
# ---------------------------------------------------------------------------
require_readiness_probe contains msg if {
    container := input.spec.containers[_]
    not container.readinessProbe
    msg := sprintf("Container %v in %v/%v is missing readinessProbe", [
        container.name, input.kind, input.metadata.name,
    ])
}

# ---------------------------------------------------------------------------
# require_liveness_probe
# ---------------------------------------------------------------------------
require_liveness_probe contains msg if {
    container := input.spec.containers[_]
    not container.livenessProbe
    msg := sprintf("Container %v in %v/%v is missing livenessProbe", [
        container.name, input.kind, input.metadata.name,
    ])
}

# ---------------------------------------------------------------------------
# require_resource_limits
# ---------------------------------------------------------------------------
require_resource_limits contains msg if {
    container := input.spec.containers[_]
    not container.resources.limits
    msg := sprintf("Container %v in %v/%v is missing resource limits", [
        container.name, input.kind, input.metadata.name,
    ])
}

require_resource_limits contains msg if {
    container := input.spec.containers[_]
    not container.resources.limits.cpu
    msg := sprintf("Container %v in %v/%v is missing CPU limit", [
        container.name, input.kind, input.metadata.name,
    ])
}

require_resource_limits contains msg if {
    container := input.spec.containers[_]
    not container.resources.limits.memory
    msg := sprintf("Container %v in %v/%v is missing memory limit", [
        container.name, input.kind, input.metadata.name,
    ])
}

# ---------------------------------------------------------------------------
# deny_host_network
# ---------------------------------------------------------------------------
deny_host_network contains msg if {
    input.spec.hostNetwork == true
    msg := sprintf("%v/%v uses host network — deny by policy", [
        input.kind, input.metadata.name,
    ])
}

# ---------------------------------------------------------------------------
# deny_host_pid
# ---------------------------------------------------------------------------
deny_host_pid contains msg if {
    input.spec.hostPID == true
    msg := sprintf("%v/%v uses host PID namespace — deny by policy", [
        input.kind, input.metadata.name,
    ])
}

# ---------------------------------------------------------------------------
# require_non_root_user
# ---------------------------------------------------------------------------
require_non_root_user contains msg if {
    container := input.spec.containers[_]
    not container.securityContext.runAsNonRoot
    msg := sprintf("Container %v in %v/%v does not set runAsNonRoot=true", [
        container.name, input.kind, input.metadata.name,
    ])
}

require_non_root_user contains msg if {
    container := input.spec.containers[_]
    container.securityContext.runAsNonRoot == false
    msg := sprintf("Container %v in %v/%v explicitly sets runAsNonRoot=false", [
        container.name, input.kind, input.metadata.name,
    ])
}

# ---------------------------------------------------------------------------
# deny_empty_ingress_hosts
# ---------------------------------------------------------------------------
deny_empty_ingress_hosts contains msg if {
    input.kind == "Ingress"
    rule := input.spec.rules[_]
    rule.host == ""
    msg := sprintf("Ingress %v has a rule with an empty host", [
        input.metadata.name,
    ])
}
