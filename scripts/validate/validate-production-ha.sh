#!/usr/bin/env bash

set -euo pipefail

OVERLAY="${OVERLAY:-infra/k8s/overlays/production}"
REPORT_DIR="${REPORT_DIR:-artifacts/security}"
REPORT_FILE="${REPORT_FILE:-${REPORT_DIR}/production-ha-readiness.md}"

mkdir -p "${REPORT_DIR}"

for cmd in kubectl ruby; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "[ERROR] Missing command: ${cmd}" >&2
    exit 2
  fi
done

rendered="$(mktemp)"
trap 'rm -f "${rendered}"' EXIT

kubectl kustomize "${OVERLAY}" > "${rendered}"

ruby -W0 -ryaml - "${rendered}" "${REPORT_FILE}" "${OVERLAY}" <<'RUBY'
rendered, report_file, overlay = ARGV
official = {
  "portal-web" => 3,
  "auth-users" => 2,
  "chatbot-manager" => 2,
  "conversation-service" => 2,
  "audit-security-service" => 2
}

docs = YAML.load_stream(File.read(rendered)).compact.select { |doc| doc.is_a?(Hash) }
deployments = docs.select { |doc| doc["kind"] == "Deployment" }.to_h { |doc| [doc.dig("metadata", "name"), doc] }
pdbs = docs.select { |doc| doc["kind"] == "PodDisruptionBudget" }.to_h { |doc| [doc.dig("metadata", "name"), doc] }
hpas = docs.select { |doc| doc["kind"] == "HorizontalPodAutoscaler" }.to_h { |doc| [doc.dig("metadata", "name"), doc] }

rows = []
failures = []

def check(rows, failures, component, control, ok, evidence)
  rows << [component, control, ok ? "TERMINÉ" : "FAIL", evidence]
  failures << "#{component}: #{control} -- #{evidence}" unless ok
end

official.each do |name, min_replicas|
  dep = deployments[name]
  check(rows, failures, name, "Deployment rendered", !dep.nil?, "Deployment #{name}")
  next unless dep

  replicas = dep.dig("spec", "replicas").to_i
  check(rows, failures, name, "replicas >= #{min_replicas}", replicas >= min_replicas, "replicas=#{replicas}")

  strategy = dep.dig("spec", "strategy") || {}
  rolling = strategy["rollingUpdate"] || {}
  check(rows, failures, name, "RollingUpdate enabled", strategy["type"] == "RollingUpdate", "strategy.type=#{strategy["type"]}")
  check(rows, failures, name, "rolling maxUnavailable=0", rolling["maxUnavailable"].to_s == "0", "maxUnavailable=#{rolling["maxUnavailable"]}")
  check(rows, failures, name, "rolling maxSurge=1", rolling["maxSurge"].to_s == "1", "maxSurge=#{rolling["maxSurge"]}")
  check(rows, failures, name, "minReadySeconds configured", dep.dig("spec", "minReadySeconds").to_i >= 10, "minReadySeconds=#{dep.dig("spec", "minReadySeconds")}")

  pod_spec = dep.dig("spec", "template", "spec") || {}
  affinity_terms = pod_spec.dig("affinity", "podAntiAffinity", "preferredDuringSchedulingIgnoredDuringExecution") || []
  anti_affinity_ok = affinity_terms.any? do |term|
    term.dig("podAffinityTerm", "topologyKey") == "kubernetes.io/hostname" &&
      term.dig("podAffinityTerm", "labelSelector", "matchLabels", "app.kubernetes.io/name") == name
  end
  check(rows, failures, name, "soft pod anti-affinity", anti_affinity_ok, "preferred anti-affinity on kubernetes.io/hostname")

  spread = pod_spec["topologySpreadConstraints"] || []
  spread_ok = spread.any? do |constraint|
    constraint["topologyKey"] == "kubernetes.io/hostname" &&
      constraint.dig("labelSelector", "matchLabels", "app.kubernetes.io/name") == name
  end
  check(rows, failures, name, "topology spread constraint", spread_ok, "topologyKey=kubernetes.io/hostname")

  %w[readinessProbe livenessProbe startupProbe].each do |probe|
    has_probe = (pod_spec["containers"] || []).all? { |container| container.key?(probe) }
    check(rows, failures, name, probe, has_probe, "all containers define #{probe}")
  end

  pdb = pdbs["#{name}-pdb"]
  check(rows, failures, name, "PDB rendered", !pdb.nil?, "#{name}-pdb")
  if pdb
    min_available = pdb.dig("spec", "minAvailable").to_i
    expected_min = name == "portal-web" ? 2 : 1
    check(rows, failures, name, "PDB minAvailable coherent", min_available >= expected_min && min_available < replicas, "minAvailable=#{min_available}, replicas=#{replicas}")
  end

  hpa = hpas[name]
  check(rows, failures, name, "HPA rendered", !hpa.nil?, "HorizontalPodAutoscaler #{name}")
  if hpa
    hpa_min = hpa.dig("spec", "minReplicas").to_i
    hpa_max = hpa.dig("spec", "maxReplicas").to_i
    metrics = hpa.dig("spec", "metrics") || []
    metric_names = metrics.map { |metric| metric.dig("resource", "name") }.compact
    check(rows, failures, name, "HPA minReplicas >= deployment floor", hpa_min >= min_replicas, "minReplicas=#{hpa_min}")
    check(rows, failures, name, "HPA maxReplicas > minReplicas", hpa_max > hpa_min, "maxReplicas=#{hpa_max}, minReplicas=#{hpa_min}")
    check(rows, failures, name, "HPA CPU and memory metrics", %w[cpu memory].all? { |m| metric_names.include?(m) }, "metrics=#{metric_names.join(",")}")
  end
end

File.open(report_file, "w") do |f|
  f.puts "# Production HA Readiness - SecureRAG Hub"
  f.puts
  f.puts "- Overlay: `#{overlay}`"
  f.puts "- Generated at UTC: `#{Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")}`"
  f.puts
  f.puts "| Component | Control | Status | Evidence |"
  f.puts "|---|---|---:|---|"
  rows.each do |component, control, status, evidence|
    f.puts "| `#{component}` | #{control} | #{status} | `#{evidence}` |"
  end
  f.puts
  f.puts "## Interpretation"
  f.puts
  if failures.empty?
    f.puts "Statut global: TERMINÉ. L'overlay production rend les controles HA statiques attendus."
  else
    f.puts "Statut global: FAIL. Les controles suivants doivent etre corriges avant de presenter l'overlay comme pret HA :"
    failures.each { |failure| f.puts "- #{failure}" }
  end
  f.puts
  f.puts "## Limite runtime"
  f.puts
  f.puts "Cette validation est statique. Les preuves runtime exigent un cluster actif, metrics-server et `kubectl get deploy,pods,pdb,hpa -n securerag-hub`."
end

if failures.empty?
  puts "[INFO] Production HA readiness validation passed. Report: #{report_file}"
else
  warn "[ERROR] Production HA readiness validation failed. Report: #{report_file}"
  failures.each { |failure| warn " - #{failure}" }
  exit 1
end
RUBY
