# File: security/conftest/policy/network.rego
# Description: Conftest policies for NetworkPolicies
# Modified by: DevSecOps Agent — 2026-06-13

package main

import future.keywords.if
import future.keywords.in

# ---------------------------------------------------------------------------
# require_default_deny
# ---------------------------------------------------------------------------
require_default_deny contains msg if {
    input.kind == "NetworkPolicy"
    input.metadata.namespace == namespace
    not is_default_deny(input)
    msg := sprintf("NetworkPolicy %v in namespace %v is not a default-deny policy", [
        input.metadata.name, input.metadata.namespace,
    ])
}

is_default_deny(policy) if {
    policy.spec.policyTypes[_] == "Ingress"
    count(policy.spec.ingress) == 0
}

is_default_deny(policy) if {
    policy.spec.policyTypes[_] == "Egress"
    count(policy.spec.egress) == 0
}

# ---------------------------------------------------------------------------
# require_network_policy
# ---------------------------------------------------------------------------
require_network_policy contains msg if {
    input.kind == "Namespace"
    not namespace_has_network_policy(input.metadata.name)
    msg := sprintf("Namespace %v has no NetworkPolicy — a default-deny policy should be applied", [
        input.metadata.name,
    ])
}

namespace_has_network_policy(ns) if {
    data.networkpolicies[_].metadata.namespace == ns
}

# ---------------------------------------------------------------------------
# deny_allow_all_ingress
# ---------------------------------------------------------------------------
deny_allow_all_ingress contains msg if {
    input.kind == "NetworkPolicy"
    ingress := input.spec.ingress[_]
    from := ingress.from[_]
    from.ipBlock.cidr == "0.0.0.0/0"
    msg := sprintf("NetworkPolicy %v allows all ingress traffic (0.0.0.0/0)", [
        input.metadata.name,
    ])
}

# ---------------------------------------------------------------------------
# deny_allow_all_egress
# ---------------------------------------------------------------------------
deny_allow_all_egress contains msg if {
    input.kind == "NetworkPolicy"
    egress := input.spec.egress[_]
    to := egress.to[_]
    to.ipBlock.cidr == "0.0.0.0/0"
    msg := sprintf("NetworkPolicy %v allows all egress traffic (0.0.0.0/0)", [
        input.metadata.name,
    ])
}
