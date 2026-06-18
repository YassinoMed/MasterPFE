#!/usr/bin/env bash
# hubble-flows.sh — Observe Real-Time Hubble Network Flows
# SecureRAG Hub — eBPF Network Observability (Phase 10)
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { printf "${GREEN}[INFO]${NC}  %s\n" "$*"; }
warn()    { printf "${YELLOW}[WARN]${NC}  %s\n" "$*"; }
error()   { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }
header()  { printf "\n${CYAN}%s${NC}\n" "$*"; }

CILIUM_NAMESPACE="kube-system"

# Find the first Cilium agent pod
CILIUM_POD=$(kubectl get pods -n "${CILIUM_NAMESPACE}" -l app.kubernetes.io/name=cilium -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

if [ -z "${CILIUM_POD}" ]; then
  error "No Cilium agent pod found in namespace ${CILIUM_NAMESPACE}"
  error "Is Cilium deployed? Run: bash scripts/ebpf/deploy-cilium.sh"
  exit 1
fi

usage() {
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  --last <N>        Show the last N observed flows (default: continuous)"
  echo "  --verdict <v>     Filter by verdict: FORWARDED, DROPPED, AUDIT, ERROR"
  echo "  --from <pod>      Filter by source pod name (partial match)"
  echo "  --to <pod>        Filter by destination pod name (partial match)"
  echo "  --port <port>     Filter by destination port"
  echo "  --protocol <p>    Filter by protocol: TCP, UDP, ICMP"
  echo "  --http            Show only HTTP flows"
  echo "  --dns             Show only DNS flows"
  echo "  --tcp             Show only TCP flows"
  echo "  --json            Output in JSON format (verbose)"
  echo "  --help            Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0                                    # Continuous real-time flows"
  echo "  $0 --last 10                          # Show last 10 flows"
  echo "  $0 --verdict DROPPED                  # Show only dropped flows"
  echo "  $0 --from portal-web                  # Flows from portal-web"
  echo "  $0 --to auth-users --port 8000        # Flows to auth-users on port 8000"
  echo "  $0 --http --last 20                   # Last 20 HTTP flows"
  echo "  $0 --dns                              # Live DNS queries"
  exit 1
}

# Parse arguments
HUBBLE_ARGS=""
VERBOSE=false
VERDICT_FILTER=""
FROM_FILTER=""
TO_FILTER=""
PORT_FILTER=""
PROTO_FILTER=""
HTTP_ONLY=false
DNS_ONLY=false
TCP_ONLY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --last)
      HUBBLE_ARGS="${HUBBLE_ARGS} --last $2"
      shift 2
      ;;
    --verdict)
      VERDICT_FILTER="$2"
      shift 2
      ;;
    --from)
      FROM_FILTER="$2"
      shift 2
      ;;
    --to)
      TO_FILTER="$2"
      shift 2
      ;;
    --port)
      PORT_FILTER="$2"
      shift 2
      ;;
    --protocol)
      PROTO_FILTER="$2"
      shift 2
      ;;
    --http)
      HTTP_ONLY=true
      shift
      ;;
    --dns)
      DNS_ONLY=true
      shift
      ;;
    --tcp)
      TCP_ONLY=true
      shift
      ;;
    --json)
      HUBBLE_ARGS="${HUBBLE_ARGS} -o jsonpb"
      VERBOSE=true
      shift
      ;;
    --help|-h)
      usage
      ;;
    *)
      error "Unknown option: $1"
      usage
      ;;
  esac
done

# Build filter expression
FILTER_EXPR=""
if [ -n "${VERDICT_FILTER}" ]; then
  FILTER_EXPR="${FILTER_EXPR} --verdict ${VERDICT_FILTER}"
fi
if [ -n "${FROM_FILTER}" ]; then
  FILTER_EXPR="${FILTER_EXPR} --from-pod ${FROM_FILTER}"
fi
if [ -n "${TO_FILTER}" ]; then
  FILTER_EXPR="${FILTER_EXPR} --to-pod ${TO_FILTER}"
fi
if [ -n "${PORT_FILTER}" ]; then
  FILTER_EXPR="${FILTER_EXPR} --port ${PORT_FILTER}"
fi
if [ -n "${PROTO_FILTER}" ]; then
  FILTER_EXPR="${FILTER_EXPR} --protocol ${PROTO_FILTER}"
fi
if [ "${HTTP_ONLY}" = true ]; then
  FILTER_EXPR="${FILTER_EXPR} --http"
fi
if [ "${DNS_ONLY}" = true ]; then
  FILTER_EXPR="${FILTER_EXPR} --dns"
fi
if [ "${TCP_ONLY}" = true ]; then
  FILTER_EXPR="${FILTER_EXPR} --protocol TCP"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  HUBBLE — NETWORK FLOW OBSERVER"
echo "═══════════════════════════════════════════════════════════════"
echo ""

info "Cilium pod: ${CILIUM_POD}"
info "Filters: ${FILTER_EXPR:-none (showing all flows)}"
if [ -z "${HUBBLE_ARGS}" ]; then
  info "Mode: real-time (continuous)"
  echo ""
  header "Flows (Ctrl+C to stop):"
else
  info "Mode: snapshot"
  echo ""
  header "Flows:"
fi

# Execute hubble observe via kubectl exec
set -x
kubectl exec -n "${CILIUM_NAMESPACE}" "${CILIUM_POD}" -- \
  hubble observe ${HUBBLE_ARGS} ${FILTER_EXPR}
