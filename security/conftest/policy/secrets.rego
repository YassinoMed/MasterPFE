# File: security/conftest/policy/secrets.rego
# Description: Conftest policies for Secrets management
# Modified by: DevSecOps Agent — 2026-06-13

package main

import future.keywords.if
import future.keywords.in

# ---------------------------------------------------------------------------
# deny_hardcoded_credentials
# ---------------------------------------------------------------------------
deny_hardcoded_credentials contains msg if {
    input.kind == "Secret"
    input.type == "Opaque"
    key := input.data[key_name]
    decoded := base64.decode(key)
    contains(lower(decoded), "password")
    msg := sprintf("Secret %v contains a value that looks like a password", [
        input.metadata.name,
    ])
}

deny_hardcoded_credentials contains msg if {
    input.kind == "ConfigMap"
    key := input.data[key_name]
    contains(lower(key), "password")
    msg := sprintf("ConfigMap %v contains a key that looks like a credential (%v)", [
        input.metadata.name, key_name,
    ])
}

deny_hardcoded_credentials contains msg if {
    input.kind == "ConfigMap"
    key := input.data[key_name]
    contains(lower(key), "token")
    msg := sprintf("ConfigMap %v contains a key that looks like a credential (%v)", [
        input.metadata.name, key_name,
    ])
}

deny_hardcoded_credentials contains msg if {
    input.kind == "ConfigMap"
    key := input.data[key_name]
    contains(lower(key), "secret")
    msg := sprintf("ConfigMap %v contains a key that looks like a credential (%v)", [
        input.metadata.name, key_name,
    ])
}

deny_hardcoded_credentials contains msg if {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    env := container.env[_]
    contains(lower(env.name), "password")
    not env.valueFrom
    msg := sprintf("Deployment %v container %v has hardcoded env %v — use ExternalSecret or Vault CSI", [
        input.metadata.name, container.name, env.name,
    ])
}

deny_hardcoded_credentials contains msg if {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    env := container.env[_]
    contains(lower(env.name), "token")
    not env.valueFrom
    msg := sprintf("Deployment %v container %v has hardcoded env %v — use ExternalSecret or Vault CSI", [
        input.metadata.name, container.name, env.name,
    ])
}

deny_hardcoded_credentials contains msg if {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    env := container.env[_]
    contains(lower(env.name), "api_key")
    not env.valueFrom
    msg := sprintf("Deployment %v container %v has hardcoded env %v — use ExternalSecret or Vault CSI", [
        input.metadata.name, container.name, env.name,
    ])
}

# ---------------------------------------------------------------------------
# require_external_secrets_ref
# ---------------------------------------------------------------------------
require_external_secrets_ref contains msg if {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    env := container.env[_]
    contains(lower(env.name), "password")
    env.valueFrom.secretKeyRef.name
    msg := sprintf("Deployment %v container %v references native Secret %v — prefer ExternalSecret or Vault CSI", [
        input.metadata.name, container.name, env.valueFrom.secretKeyRef.name,
    ])
}

require_external_secrets_ref contains msg if {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    env := container.env[_]
    contains(lower(env.name), "password")
    env.valueFrom.configMapKeyRef.name
    msg := sprintf("Deployment %v container %v references ConfigMap %v for password — use ExternalSecret or Vault CSI", [
        input.metadata.name, container.name, env.valueFrom.configMapKeyRef.name,
    ])
}
