#!/usr/bin/env bash
# Fichier : scripts/dora/collect-dora-metrics.sh
# Collecte les métriques DORA depuis GitHub API, Jenkins API et Kubernetes,
# puis les expose au format Prometheus (textfile collector).

set -euo pipefail

GITHUB_TOKEN="${GITHUB_TOKEN:-}"
GITHUB_OWNER="${GITHUB_OWNER:-securerag}"
GITHUB_REPO="${GITHUB_REPO:-hub}"
JENKINS_URL="${JENKINS_URL:-http://jenkins:8080}"
JENKINS_USER="${JENKINS_USER:-admin}"
JENKINS_PASS="${JENKINS_PASS:-}"
NAMESPACES="${NAMESPACES:-securerag-hub}"
OUTPUT_FILE="${OUTPUT_FILE:-/var/lib/node_exporter/textfile_collector/dora-metrics.prom}"

info() { printf '[INFO] %s\n' "$*"; }
error() { printf '[ERROR] %s\n' "$*" >&2; }

command -v curl >/dev/null 2>&1 || { error "curl is required"; exit 2; }
command -v kubectl >/dev/null 2>&1 || { error "kubectl is required"; exit 2; }
command -v jq >/dev/null 2>&1 || { error "jq is required"; exit 2; }

mkdir -p "$(dirname "${OUTPUT_FILE}")"

metrics=""
add_metric() {
  local name="$1" value="$2" labels="${3:-}"
  if [[ -n "${labels}" ]]; then
    metrics+="${name}{${labels}} ${value}\n"
  else
    metrics+="${name} ${value}\n"
  fi
}

# --- Deployment Frequency (from Kubernetes rollouts) ---
ns_list="${NAMESPACES}"
for ns in ${ns_list//,/ }; do
  deployments="$(kubectl get deployments -n "${ns}" -o json 2>/dev/null || true)"
  if [[ -z "${deployments}" ]]; then
    info "No deployments found in namespace ${ns}"
    continue
  fi
  dep_count="$(echo "${deployments}" | jq '.items | length')"
  # Count revision changes per deployment as proxy for deployments
  for dep_name in $(echo "${deployments}" | jq -r '.items[].metadata.name'); do
    rev="$(kubectl get deployment "${dep_name}" -n "${ns}" -o jsonpath='{.metadata.annotations.deployment\.kubernetes\.io/revision}' 2>/dev/null || echo "1")"
    # Export current revision as a gauge — diff over time gives deployment frequency
    add_metric "kubernetes_deployment_revision" "${rev}" "service=\"${dep_name}\",namespace=\"${ns}\""
  done
done

# --- Lead Time for Changes (from GitHub commits to deployment) ---
if [[ -n "${GITHUB_TOKEN}" ]]; then
  # Fetch recent commits from default branch
  commits_json="$(curl -s -H "Authorization: token ${GITHUB_TOKEN}" \
    "https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/commits?per_page=30" 2>/dev/null || true)"
  if [[ -n "${commits_json}" ]]; then
    commit_count="$(echo "${commits_json}" | jq 'length' 2>/dev/null || echo 0)"
    add_metric "github_commits_count" "${commit_count}" "repo=\"${GITHUB_OWNER}/${GITHUB_REPO}\""
    # Compute approximate lead time as age of oldest commit in window
    oldest_ts="$(echo "${commits_json}" | jq -r 'last.commit.comitter.date // last.commit.author.date // empty' 2>/dev/null || true)"
    if [[ -n "${oldest_ts}" ]]; then
      oldest_epoch="$(date -d "${oldest_ts}" +%s 2>/dev/null || echo 0)"
      now_epoch="$(date +%s)"
      lead_time=$(( now_epoch - oldest_epoch ))
      add_metric "ci_commit_to_deploy_lead_seconds" "${lead_time}" "repo=\"${GITHUB_OWNER}/${GITHUB_REPO}\""
    fi
  fi
fi

# --- Jenkins pipeline metrics ---
if [[ -n "${JENKINS_USER}" && -n "${JENKINS_PASS}" ]]; then
  jobs_json="$(curl -fsS -u "${JENKINS_USER}:${JENKINS_PASS}" \
    "${JENKINS_URL}/api/json?tree=jobs[name,color,lastBuild[number,result,timestamp,duration]]" 2>/dev/null || true)"
  if [[ -n "${jobs_json}" ]]; then
    for job_name in $(echo "${jobs_json}" | jq -r '.jobs[].name // empty' 2>/dev/null); do
      result="$(echo "${jobs_json}" | jq -r --arg n "${job_name}" '.jobs[] | select(.name==$n) | .lastBuild.result // "UNKNOWN"' 2>/dev/null)"
      duration="$(echo "${jobs_json}" | jq -r --arg n "${job_name}" '.jobs[] | select(.name==$n) | .lastBuild.duration // 0' 2>/dev/null)"
      add_metric "jenkins_build_result" "1" "job=\"${job_name}\",result=\"${result}\""
      add_metric "jenkins_build_duration_seconds" "${duration}" "job=\"${job_name}\""
    done
  fi

  # Pipeline success/failure rate from Jenkins API (last 100 builds per job)
  for job_name in $(echo "${jobs_json}" | jq -r '.jobs[].name // empty' 2>/dev/null); do
    build_json="$(curl -fsS -u "${JENKINS_USER}:${JENKINS_PASS}" \
      "${JENKINS_URL}/job/${job_name}/api/json?tree=builds[number,result,timestamp,duration]{0,100}" 2>/dev/null || true)"
    if [[ -n "${build_json}" ]]; then
      total="$(echo "${build_json}" | jq '.builds | length' 2>/dev/null || echo 0)"
      failed="$(echo "${build_json}" | jq '[.builds[] | select(.result=="FAILURE")] | length' 2>/dev/null || echo 0)"
      if [[ "${total}" -gt 0 ]]; then
        fail_rate="$(echo "scale=6; ${failed} / ${total}" | bc 2>/dev/null || echo 0)"
        add_metric "jenkins_pipeline_failure_ratio" "${fail_rate}" "job=\"${job_name}\""
      fi
    fi
  done
fi

# --- Alert resolution duration (MTTR proxy from Kubernetes events) ---
for ns in ${ns_list//,/ }; do
  events="$(kubectl get events -n "${ns}" --sort-by='.lastTimestamp' -o json 2>/dev/null || true)"
  if [[ -n "${events}" ]]; then
    alert_count="$(echo "${events}" | jq '[.items[] | select(.type=="Warning")] | length' 2>/dev/null || echo 0)"
    add_metric "kubernetes_alert_warning_count" "${alert_count}" "namespace=\"${ns}\""
    # Compute avg resolution time from events with both first/last timestamps
    resolution_sum=0
    resolution_n=0
    while IFS=$'\n' read -r ev; do
      first_ts="$(echo "${ev}" | jq -r '.firstTimestamp // empty' 2>/dev/null)"
      last_ts="$(echo "${ev}" | jq -r '.lastTimestamp // empty' 2>/dev/null)"
      if [[ -n "${first_ts}" && -n "${last_ts}" && "${first_ts}" != "null" && "${last_ts}" != "null" ]]; then
        first_epoch="$(date -d "${first_ts}" +%s 2>/dev/null || echo 0)"
        last_epoch="$(date -d "${last_ts}" +%s 2>/dev/null || echo 0)"
        if [[ "${first_epoch}" -gt 0 && "${last_epoch}" -gt 0 ]]; then
          resolution_sum=$(( resolution_sum + last_epoch - first_epoch ))
          resolution_n=$(( resolution_n + 1 ))
        fi
      fi
    done < <(echo "${events}" | jq -c '.items[] | select(.type=="Warning")' 2>/dev/null)
    if [[ "${resolution_n}" -gt 0 ]]; then
      avg_resolution=$(( resolution_sum / resolution_n ))
      add_metric "alert_resolution_duration_seconds" "${avg_resolution}" "namespace=\"${ns}\""
    fi
  fi
done

# --- Write Prometheus metrics output ---
{
  printf '# HELP dora_deployment_frequency Deployment frequency (deployments per day) rolling 7d.\n'
  printf '# TYPE dora_deployment_frequency gauge\n'
  printf '# HELP dora_lead_time_seconds Lead time for changes from commit to deployment.\n'
  printf '# TYPE dora_lead_time_seconds gauge\n'
  printf '# HELP dora_mttr_seconds Mean time to recovery (alert to resolution).\n'
  printf '# TYPE dora_mttr_seconds gauge\n'
  printf '# HELP dora_change_failure_ratio Change failure rate (failed / total deployments).\n'
  printf '# TYPE dora_change_failure_ratio gauge\n'
  printf '# HELP dora_commit_count Number of recent GitHub commits.\n'
  printf '# TYPE dora_commit_count gauge\n'
  printf '# HELP dora_jenkins_build_result Jenkins build result indicator.\n'
  printf '# TYPE dora_jenkins_build_result gauge\n'
  printf '# HELP dora_jenkins_build_duration_seconds Jenkins build duration.\n'
  printf '# TYPE dora_jenkins_build_duration_seconds gauge\n'
  printf '# HELP dora_jenkins_pipeline_failure_ratio Jenkins pipeline failure ratio.\n'
  printf '# TYPE dora_jenkins_pipeline_failure_ratio gauge\n'
  printf '# HELP dora_alert_warning_count Warning event count per namespace.\n'
  printf '# TYPE dora_alert_warning_count gauge\n'
  printf '# HELP dora_alert_resolution_duration_seconds Average alert resolution duration.\n'
  printf '# TYPE dora_alert_resolution_duration_seconds gauge\n'
  printf '%b' "${metrics}"
} > "${OUTPUT_FILE}"

info "DORA metrics written to ${OUTPUT_FILE}"
