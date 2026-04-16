#!/usr/bin/env bash

set -euo pipefail

REPORT_DIR="${REPORT_DIR:-artifacts/security}"
REPORT_FILE="${REPORT_DIR}/k8s-ultra-hardening.md"
OVERLAYS=(
  "infra/k8s/overlays/dev"
  "infra/k8s/overlays/demo"
)
POLICY_OVERLAYS=(
  "infra/k8s/policies/kyverno"
  "infra/k8s/policies/kyverno-enforce"
)

mkdir -p "${REPORT_DIR}"

for cmd in kubectl ruby; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "[ERROR] Missing command: ${cmd}" >&2
    exit 1
  fi
done

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

for overlay in "${OVERLAYS[@]}"; do
  kubectl kustomize "${overlay}" > "${tmp_dir}/$(basename "${overlay}").yaml"
done

for overlay in "${POLICY_OVERLAYS[@]}"; do
  kubectl kustomize "${overlay}" > "${tmp_dir}/$(basename "${overlay}")-policies.yaml"
done

ruby -W0 -ryaml - "${tmp_dir}" "${REPORT_FILE}" <<'RUBY'
tmp_dir, report_file = ARGV
official = %w[portal-web auth-users chatbot-manager conversation-service audit-security-service]
required_policy_names = %w[
  securerag-audit-cleartext-env-values
  securerag-require-pod-security
  securerag-require-workload-controls
  securerag-restrict-image-references
  securerag-restrict-service-exposure
  securerag-restrict-volume-types
  securerag-verify-cosign-images
]

failures = []
rows = []

def dig(hash, *keys)
  keys.reduce(hash) { |acc, key| acc.is_a?(Hash) ? acc[key] : nil }
end

def check(condition, failures, rows, overlay, control, evidence)
  if condition
    rows << [overlay, control, "TERMINÉ", evidence]
  else
    failures << "#{overlay}: #{control} -- #{evidence}"
    rows << [overlay, control, "FAIL", evidence]
  end
end

Dir.glob(File.join(tmp_dir, "*.yaml")).sort.each do |path|
  overlay = File.basename(path, ".yaml")
  docs = YAML.load_stream(File.read(path)).compact.select { |doc| doc.is_a?(Hash) }

  if overlay.end_with?("-policies")
    policies = docs.select { |doc| doc["kind"] == "ClusterPolicy" }
    names = policies.map { |doc| dig(doc, "metadata", "name") }
    required_policy_names.each do |name|
      check(names.include?(name), failures, rows, overlay, "Kyverno policy #{name} rendered", "ClusterPolicy present")
    end

    if overlay == "kyverno-enforce-policies"
      policies.each do |policy|
        check(
          dig(policy, "spec", "validationFailureAction") == "Enforce",
          failures,
          rows,
          overlay,
          "#{dig(policy, "metadata", "name")} is Enforce",
          "validationFailureAction=Enforce"
        )
      end
    end
    next
  end

  namespace = docs.find { |doc| doc["kind"] == "Namespace" && dig(doc, "metadata", "name") == "securerag-hub" }
  labels = dig(namespace || {}, "metadata", "labels") || {}
  check(labels["pod-security.kubernetes.io/enforce"] == "restricted", failures, rows, overlay, "Pod Security Admission enforce restricted", "namespace label enforce=restricted")
  check(labels["pod-security.kubernetes.io/audit"] == "restricted", failures, rows, overlay, "Pod Security Admission audit restricted", "namespace label audit=restricted")
  check(labels["pod-security.kubernetes.io/warn"] == "restricted", failures, rows, overlay, "Pod Security Admission warn restricted", "namespace label warn=restricted")

  service_accounts = docs.select { |doc| doc["kind"] == "ServiceAccount" }
  (official.map { |name| "sa-#{name}" } + ["sa-validation"]).each do |sa|
    sa_doc = service_accounts.find { |doc| dig(doc, "metadata", "name") == sa }
    check(!sa_doc.nil? && sa_doc["automountServiceAccountToken"] == false, failures, rows, overlay, "ServiceAccount #{sa} token automount disabled", "automountServiceAccountToken=false")
  end

  deployments = docs.select { |doc| doc["kind"] == "Deployment" }
  deployments_by_name = deployments.to_h { |doc| [dig(doc, "metadata", "name"), doc] }
  official.each do |name|
    dep = deployments_by_name[name]
    check(!dep.nil?, failures, rows, overlay, "Deployment #{name} rendered", "Deployment present")
    next unless dep

    pod_spec = dig(dep, "spec", "template", "spec") || {}
    pod_sc = pod_spec["securityContext"] || {}
    containers = pod_spec["containers"] || []
    volumes = pod_spec["volumes"] || []

    check(pod_spec["serviceAccountName"].to_s != "" && pod_spec["serviceAccountName"] != "default", failures, rows, overlay, "#{name} explicit non-default ServiceAccount", pod_spec["serviceAccountName"].to_s)
    check(pod_spec["automountServiceAccountToken"] == false, failures, rows, overlay, "#{name} token automount disabled", "automountServiceAccountToken=false")
    check(pod_sc["runAsNonRoot"] == true, failures, rows, overlay, "#{name} pod runs as non-root", "runAsNonRoot=true")
    check(dig(pod_sc, "seccompProfile", "type") == "RuntimeDefault", failures, rows, overlay, "#{name} RuntimeDefault seccomp", "seccompProfile=RuntimeDefault")
    check(!pod_spec.fetch("hostNetwork", false), failures, rows, overlay, "#{name} hostNetwork disabled", "hostNetwork=false/absent")
    check(!pod_spec.fetch("hostPID", false), failures, rows, overlay, "#{name} hostPID disabled", "hostPID=false/absent")
    check(!pod_spec.fetch("hostIPC", false), failures, rows, overlay, "#{name} hostIPC disabled", "hostIPC=false/absent")
    check(volumes.none? { |volume| volume.key?("hostPath") }, failures, rows, overlay, "#{name} no hostPath volume", "hostPath absent")

    containers.each do |container|
      cname = container["name"]
      sc = container["securityContext"] || {}
      resources = container["resources"] || {}
      requests = resources["requests"] || {}
      limits = resources["limits"] || {}
      image = container["image"].to_s

      check(sc["allowPrivilegeEscalation"] == false, failures, rows, overlay, "#{name}/#{cname} privilege escalation disabled", "allowPrivilegeEscalation=false")
      check(sc["readOnlyRootFilesystem"] == true, failures, rows, overlay, "#{name}/#{cname} read-only root filesystem", "readOnlyRootFilesystem=true")
      check((dig(sc, "capabilities", "drop") || []).include?("ALL"), failures, rows, overlay, "#{name}/#{cname} drops all capabilities", "capabilities.drop includes ALL")
      %w[cpu memory ephemeral-storage].each do |resource|
        check(requests.key?(resource) && limits.key?(resource), failures, rows, overlay, "#{name}/#{cname} #{resource} request and limit", "requests/limits #{resource}")
      end
      %w[readinessProbe livenessProbe startupProbe].each do |probe|
        check(container.key?(probe), failures, rows, overlay, "#{name}/#{cname} #{probe}", "#{probe} present")
      end
      check(!image.end_with?(":latest"), failures, rows, overlay, "#{name}/#{cname} image not latest", image)
    end
  end

  services = docs.select { |doc| doc["kind"] == "Service" }
  services.each do |svc|
    name = dig(svc, "metadata", "name")
    type = dig(svc, "spec", "type") || "ClusterIP"
    allowed = type == "ClusterIP" || (name == "portal-web" && type == "NodePort")
    check(allowed, failures, rows, overlay, "Service #{name} exposure restricted", "type=#{type}")
  end

  pdb_names = docs.select { |doc| doc["kind"] == "PodDisruptionBudget" }.map { |doc| dig(doc, "metadata", "name").to_s }
  official.each do |name|
    check(pdb_names.any? { |pdb| pdb.include?(name) }, failures, rows, overlay, "PDB for #{name}", "PodDisruptionBudget present")
  end

  netpols = docs.select { |doc| doc["kind"] == "NetworkPolicy" }
  netpol_names = netpols.map { |doc| dig(doc, "metadata", "name") }
  %w[default-deny-all allow-dns-egress allow-validation-ingress allow-validation-egress].each do |name|
    check(netpol_names.include?(name), failures, rows, overlay, "NetworkPolicy #{name}", "NetworkPolicy present")
  end

  official.each do |name|
    has_selector = netpols.any? do |np|
      labels = dig(np, "spec", "podSelector", "matchLabels") || {}
      exprs = dig(np, "spec", "podSelector", "matchExpressions") || []
      labels["app.kubernetes.io/name"] == name ||
        exprs.any? { |expr| expr["key"] == "app.kubernetes.io/name" && Array(expr["values"]).include?(name) }
    end
    check(has_selector, failures, rows, overlay, "NetworkPolicy selects #{name}", "podSelector covers #{name}")
  end
end

File.open(report_file, "w") do |f|
  f.puts "# Kubernetes Ultra Hardening Validation - SecureRAG Hub"
  f.puts
  f.puts "| Overlay | Control | Status | Evidence |"
  f.puts "|---|---|---:|---|"
  rows.each do |overlay, control, status, evidence|
    f.puts "| `#{overlay}` | #{control} | #{status} | `#{evidence}` |"
  end
  f.puts
  f.puts "## Interpretation"
  f.puts
  if failures.empty?
    f.puts "Statut global: TERMINÉ for static Kubernetes hardening render checks."
  else
    f.puts "Statut global: FAIL. Correct the listed controls before declaring the overlay hardened."
    f.puts
    failures.each { |failure| f.puts "- #{failure}" }
  end
end

if failures.empty?
  puts "[INFO] Kubernetes ultra hardening validation passed. Report: #{report_file}"
else
  warn "[ERROR] Kubernetes ultra hardening validation failed. Report: #{report_file}"
  failures.each { |failure| warn " - #{failure}" }
  exit 1
end
RUBY
