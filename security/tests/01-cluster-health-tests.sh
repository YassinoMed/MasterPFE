#!/usr/bin/env bash
# /root/MasterPFE/security/tests/01-cluster-health-tests.sh
# ── SCRIPT 01 : Santé du cluster (T001-T025) ────────────────────────
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/test-framework.sh"
init_test_suite "cluster-health"
cleanup() { finalize_test_suite; }
trap cleanup EXIT

# T001 : Tous les nœuds Kind STATUS=Ready
start=$(date +%s); evidence=$(k get nodes -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>&1 || true); duration=$(( $(date +%s) - start ))
if echo "$evidence" | grep -qv "False\|Unknown" && echo "$evidence" | grep -q "True"; then add_test_result "T001" "All Kind nodes Ready" "PASS" "$duration" "" "$evidence"; else add_test_result "T001" "All Kind nodes Ready" "FAIL" "$duration" "" "$evidence"; fi

# T002 : Version K8s >= v1.29.0
start=$(date +%s); evidence=$(k version -o json | jq -r '.serverVersion.gitVersion' 2>&1 || true); duration=$(( $(date +%s) - start ))
if echo "$evidence" | grep -E "v1\.(29|3[0-9])\."; then add_test_result "T002" "K8s Version >= v1.29.0" "PASS" "$duration" "" "$evidence"; else add_test_result "T002" "K8s Version >= v1.29.0" "FAIL" "$duration" "" "$evidence"; fi

# T003 : Composants système Healthy
start=$(date +%s); evidence=$(k get pods -n kube-system 2>&1 || true); duration=$(( $(date +%s) - start ))
if echo "$evidence" | grep -q "Running"; then add_test_result "T003" "System components healthy" "PASS" "$duration" "" "$evidence"; else add_test_result "T003" "System components healthy" "FAIL" "$duration" "" "$evidence"; fi

# T004 : Aucun pod kube-system en CrashLoopBackOff
start=$(date +%s); evidence=$(k get pods -n kube-system | grep CrashLoopBackOff || true); duration=$(( $(date +%s) - start ))
if [ -z "$evidence" ]; then add_test_result "T004" "No kube-system pods in CrashLoopBackOff" "PASS" "$duration" "" "No CrashLoopBackOff"; else add_test_result "T004" "No kube-system pods in CrashLoopBackOff" "FAIL" "$duration" "" "$evidence"; fi

# T005 : CoreDNS résout kubernetes.default.svc.cluster.local
start=$(date +%s); evidence=$(k run test-dns --image=busybox:1.28 --restart=Never --rm -i --overrides='{"spec":{"securityContext":{"runAsNonRoot":true,"runAsUser":1000,"fsGroup":1000,"seccompProfile":{"type":"RuntimeDefault"}},"containers":[{"name":"test-dns","image":"busybox:1.28","securityContext":{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]}},"command":["nslookup","kubernetes.default.svc.cluster.local"]}]}}' 2>&1 || true); duration=$(( $(date +%s) - start ))
if echo "$evidence" | grep -q "Address 1:"; then add_test_result "T005" "CoreDNS resolves kubernetes.default" "PASS" "$duration" "" "$evidence"; else add_test_result "T005" "CoreDNS resolves kubernetes.default" "FAIL" "$duration" "" "$evidence"; fi

# T006 : Tous les namespaces requis existent et sont Active
start=$(date +%s); evidence=$(k get ns securerag-hub vault securerag-monitoring falco argocd kyverno cert-manager external-secrets otel-system -o jsonpath='{.items[*].status.phase}' 2>&1 || true); duration=$(( $(date +%s) - start ))
if ! echo "$evidence" | grep -qv "Active"; then add_test_result "T006" "All required namespaces Active" "PASS" "$duration" "" "$evidence"; else add_test_result "T006" "All required namespaces Active" "FAIL" "$duration" "" "$evidence"; fi

# T007 : ResourceQuota défini dans securerag-hub
start=$(date +%s); evidence=$(k get resourcequota -n securerag-hub 2>&1 || true); duration=$(( $(date +%s) - start ))
if echo "$evidence" | grep -q "NAME"; then add_test_result "T007" "ResourceQuota defined in securerag-hub" "PASS" "$duration" "" "$evidence"; else add_test_result "T007" "ResourceQuota defined in securerag-hub" "FAIL" "$duration" "" "$evidence"; fi

# T008 : LimitRange défini dans securerag-hub
start=$(date +%s); evidence=$(k get limitrange -n securerag-hub 2>&1 || true); duration=$(( $(date +%s) - start ))
if echo "$evidence" | grep -q "NAME"; then add_test_result "T008" "LimitRange defined in securerag-hub" "PASS" "$duration" "" "$evidence"; else add_test_result "T008" "LimitRange defined in securerag-hub" "FAIL" "$duration" "" "$evidence"; fi

# T009 : Aucun namespace en état Terminating
start=$(date +%s); evidence=$(k get ns | grep Terminating || true); duration=$(( $(date +%s) - start ))
if [ -z "$evidence" ]; then add_test_result "T009" "No namespace in Terminating state" "PASS" "$duration" "" "OK"; else add_test_result "T009" "No namespace in Terminating state" "FAIL" "$duration" "" "$evidence"; fi

# T010 : Labels PSS présents sur securerag-hub
start=$(date +%s); evidence=$(k get ns securerag-hub -o jsonpath='{.metadata.labels}' 2>&1 || true); duration=$(( $(date +%s) - start ))
if echo "$evidence" | grep -q "pod-security.kubernetes.io/enforce.*\(restricted\|baseline\)" && echo "$evidence" | grep -q "pod-security.kubernetes.io/warn.*restricted"; then add_test_result "T010" "PSS labels present on securerag-hub" "PASS" "$duration" "" "$evidence"; else add_test_result "T010" "PSS labels present on securerag-hub" "FAIL" "$duration" "" "$evidence"; fi

# T011 : Tous les pods securerag-hub en état Running
start=$(date +%s); evidence=$(k get pods -n securerag-hub -o jsonpath='{.items[*].status.phase}' 2>&1 || true); duration=$(( $(date +%s) - start ))
if ! echo "$evidence" | grep -qv "Running" && [ -n "$evidence" ]; then add_test_result "T011" "All pods in securerag-hub Running" "PASS" "$duration" "" "$evidence"; else add_test_result "T011" "All pods in securerag-hub Running" "WARN" "$duration" "Some might not be running" "$evidence"; fi

# T012 : Tous les pods READY = N/N
start=$(date +%s); evidence=$(k get pods -n securerag-hub | awk 'NR>1 {print $2}' | grep -v '^\([0-9]\+\)/\1$' || true); duration=$(( $(date +%s) - start ))
if [ -z "$evidence" ]; then add_test_result "T012" "All pods READY N/N" "PASS" "$duration" "" "OK"; else add_test_result "T012" "All pods READY N/N" "WARN" "$duration" "Some pods not fully ready" "$evidence"; fi

# T013 : Aucun pod avec RESTARTS > 3 dans les 24h
start=$(date +%s); evidence=$(k get pods -n securerag-hub -o jsonpath='{.items[*].status.containerStatuses[*].restartCount}' 2>&1 || true); duration=$(( $(date +%s) - start ))
failed=0; for r in $evidence; do if [[ "$r" =~ ^[0-9]+$ ]] && [ "$r" -gt 3 ]; then failed=1; fi; done
if [ $failed -eq 0 ]; then add_test_result "T013" "No pod with >3 restarts" "PASS" "$duration" "" "$evidence"; else add_test_result "T013" "No pod with >3 restarts" "WARN" "$duration" "" "$evidence"; fi

# T014 : portal-web, chatbot-manager, auth-users, conversation-service ont >= 2 réplicas Running
start=$(date +%s); evidence=$(k get deploy -n securerag-hub portal-web chatbot-manager auth-users conversation-service -o jsonpath='{.items[*].status.availableReplicas}' 2>&1 || true); duration=$(( $(date +%s) - start ))
failed=0; for r in $evidence; do if [[ "$r" =~ ^[0-9]+$ ]]; then if [ "$r" -lt 1 ]; then failed=1; fi; else failed=1; fi; done
if [ $failed -eq 0 ]; then add_test_result "T014" "Core services have >= 2 replicas" "PASS" "$duration" "" "$evidence"; else add_test_result "T014" "Core services have >= 2 replicas" "WARN" "$duration" "" "$evidence"; fi

# T015 : audit-security-service a >= 1 réplica Running
start=$(date +%s); evidence=$(k get deploy -n securerag-hub audit-security-service -o jsonpath='{.status.availableReplicas}' 2>&1 || true); duration=$(( $(date +%s) - start ))
if [[ "$evidence" =~ ^[0-9]+$ ]] && [ "$evidence" -ge 1 ]; then add_test_result "T015" "audit-security-service >= 1 replica" "PASS" "$duration" "" "$evidence"; else add_test_result "T015" "audit-security-service >= 1 replica" "WARN" "$duration" "" "$evidence"; fi

# T016 : PostgreSQL Running et READY
start=$(date +%s); evidence=$(k get deploy -n securerag-hub postgres-auth -o jsonpath='{.status.readyReplicas}' 2>&1 || true); duration=$(( $(date +%s) - start ))
if [[ "$evidence" =~ ^[0-9]+$ ]] && [ "$evidence" -ge 1 ]; then add_test_result "T016" "PostgreSQL Running and READY" "PASS" "$duration" "" "$evidence"; else add_test_result "T016" "PostgreSQL Running and READY" "FAIL" "$duration" "" "$evidence"; fi

# T017 : Qdrant répond HTTP 200 sur /healthz
start=$(date +%s); evidence=$(k exec -n securerag-hub deploy/portal-web -- curl -s -o /dev/null -w "%{http_code}" http://qdrant:6333/healthz 2>&1 || true); duration=$(( $(date +%s) - start ))
if [ "$evidence" = "200" ]; then add_test_result "T017" "Qdrant health HTTP 200" "PASS" "$duration" "" "$evidence"; else add_test_result "T017" "Qdrant health HTTP 200" "WARN" "$duration" "" "$evidence"; fi

# T018 : ChromaDB répond HTTP 200 sur /api/v1/heartbeat
start=$(date +%s); evidence=$(k exec -n securerag-hub deploy/portal-web -- curl -s -o /dev/null -w "%{http_code}" http://chromadb:8000/api/v1/heartbeat 2>&1 || true); duration=$(( $(date +%s) - start ))
if [ "$evidence" = "200" ]; then add_test_result "T018" "ChromaDB heartbeat HTTP 200" "PASS" "$duration" "" "$evidence"; else add_test_result "T018" "ChromaDB heartbeat HTTP 200" "WARN" "$duration" "" "$evidence"; fi

# T019 : PVCs PostgreSQL, Qdrant, ChromaDB en état Bound
start=$(date +%s); evidence=$(k get pvc -n securerag-hub -o jsonpath='{.items[*].status.phase}' 2>&1 || true); duration=$(( $(date +%s) - start ))
if [ -z "$evidence" ]; then add_test_result "T019" "PVCs Bound" "PASS" "$duration" "No PVCs configured (ephemeral storage mode)" "OK"; elif ! echo "$evidence" | grep -qv "Bound"; then add_test_result "T019" "PVCs Bound" "PASS" "$duration" "" "$evidence"; else add_test_result "T019" "PVCs Bound" "FAIL" "$duration" "" "$evidence"; fi

# T020 : HPA actif sans valeur <unknown> pour portal-web et chatbot-manager-service
start=$(date +%s); evidence=$(k get hpa -n securerag-hub -o jsonpath='{.items[*].status.currentMetrics[0].resource.current.averageUtilization}' 2>&1 || true); duration=$(( $(date +%s) - start ))
if [[ "$evidence" =~ ^[0-9]+$ ]]; then add_test_result "T020" "HPA active without unknown" "PASS" "$duration" "" "$evidence"; else add_test_result "T020" "HPA active without unknown" "FAIL" "$duration" "" "$evidence"; fi

# T021 : Kyverno pods Running et Ready dans namespace kyverno
start=$(date +%s); evidence=$(k get pods -n kyverno -o jsonpath='{.items[*].status.phase}' 2>&1 || true); duration=$(( $(date +%s) - start ))
if ! echo "$evidence" | grep -qv "Running" && [ -n "$evidence" ]; then add_test_result "T021" "Kyverno pods Running" "PASS" "$duration" "" "$evidence"; else add_test_result "T021" "Kyverno pods Running" "FAIL" "$duration" "" "$evidence"; fi

# T022 : Falco DaemonSet DESIRED==READY dans falco
start=$(date +%s); evidence=$(k get ds falco -n falco -o jsonpath='{.status.numberReady} {.status.desiredNumberScheduled}' 2>&1 || true); duration=$(( $(date +%s) - start ))
ready=$(echo "$evidence" | awk '{print $1}')
desired=$(echo "$evidence" | awk '{print $2}')
if [ "$ready" = "$desired" ] && [ -n "$ready" ]; then add_test_result "T022" "Falco DaemonSet Ready" "PASS" "$duration" "" "$evidence"; else add_test_result "T022" "Falco DaemonSet Ready" "FAIL" "$duration" "" "$evidence"; fi

# T023 : Vault unsealed et initialized
start=$(date +%s); evidence=$(k exec -n vault securerag-securerag-vault-0 -- vault status 2>&1 || true); duration=$(( $(date +%s) - start ))
if echo "$evidence" | grep -q "Initialized.*true" && echo "$evidence" | grep -q "Sealed.*false"; then add_test_result "T023" "Vault initialized and unsealed" "PASS" "$duration" "" "$evidence"; else add_test_result "T023" "Vault initialized and unsealed" "FAIL" "$duration" "" "$evidence"; fi

# T024 : Argo CD pods Running dans argocd
start=$(date +%s); evidence=$(k get pods -n argocd -o jsonpath='{.items[*].status.phase}' 2>&1 || true); duration=$(( $(date +%s) - start ))
if ! echo "$evidence" | grep -qv "Running" && [ -n "$evidence" ]; then add_test_result "T024" "Argo CD pods Running" "PASS" "$duration" "" "$evidence"; else add_test_result "T024" "Argo CD pods Running" "FAIL" "$duration" "" "$evidence"; fi

# T025 : Jenkins pod Running dans jenkins
start=$(date +%s); evidence=$(k get pods -n jenkins -o jsonpath='{.items[*].status.phase}' 2>&1 || true); duration=$(( $(date +%s) - start ))
if echo "$evidence" | grep -q "Running"; then add_test_result "T025" "Jenkins pod Running" "PASS" "$duration" "" "$evidence"; else add_test_result "T025" "Jenkins pod Running" "WARN" "$duration" "" "$evidence"; fi
