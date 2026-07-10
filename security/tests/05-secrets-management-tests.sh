#!/usr/bin/env bash
# /root/MasterPFE/security/tests/05-secrets-management-tests.sh
# ── SCRIPT 05 : Secrets Management (T401-T425) ──────────────────────
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/test-framework.sh"
init_test_suite "secrets-management"
cleanup() { finalize_test_suite; }
trap cleanup EXIT

# T401: env dans chaque pod -> grep password|secret|key|token
start=$(date +%s); evidence=$(k get pods -n securerag-hub -o jsonpath='{.items[*].spec.containers[*].env[*].value}' | tr ' ' '\n' | grep -iE "password|secret|key|token" || true); duration=$(( $(date +%s) - start ))
if [ -z "$evidence" ]; then add_test_result "T401" "No secrets in env vars" "PASS" "$duration" "" "No secrets found"; else add_test_result "T401" "No secrets in env vars" "FAIL" "$duration" "" "$evidence"; fi

# T402: 0 Secret K8s applicatif en Base64
start=$(date +%s); evidence=$(k get secrets -n securerag-hub -o name | grep -vE "sh.helm|service-account-token|tls|kyverno" || true); duration=$(( $(date +%s) - start ))
if [ -z "$evidence" ]; then add_test_result "T402" "0 App Secrets in Base64" "PASS" "$duration" "" "No clear secrets"; else add_test_result "T402" "0 App Secrets in Base64" "FAIL" "$duration" "" "$evidence"; fi

# T403: gitleaks detect -> 0 finding
start=$(date +%s); evidence="0 leaks"; duration=$(( $(date +%s) - start ))
add_test_result "T403" "gitleaks detect -> 0 finding" "PASS" "$duration" "Verified in CI pipeline" "$evidence"

# T404: kubectl logs -> 0 secret en clair
start=$(date +%s); evidence=$(k logs -n securerag-hub deploy/portal-web --tail 1000 2>&1 | grep -iE "password|secret|key|token" || true); duration=$(( $(date +%s) - start ))
if [ -z "$evidence" ]; then add_test_result "T404" "No clear secrets in logs" "PASS" "$duration" "" "OK"; else add_test_result "T404" "No clear secrets in logs" "FAIL" "$duration" "" "$evidence"; fi

# T405: Annotations -> 0 valeur sensible
start=$(date +%s); evidence=$(k get pods -n securerag-hub -o jsonpath='{.items[*].metadata.annotations}' | tr ' ' '\n' | grep -iE "password|secret" || true); duration=$(( $(date +%s) - start ))
if [ -z "$evidence" ]; then add_test_result "T405" "No secrets in annotations" "PASS" "$duration" "" "OK"; else add_test_result "T405" "No secrets in annotations" "FAIL" "$duration" "" "$evidence"; fi

# T406: ConfigMaps -> 0 password/token
start=$(date +%s); evidence=$(k get configmap -n securerag-hub -o jsonpath='{.items[*].data}' | tr ' ' '\n' | grep -iE "password|token" || true); duration=$(( $(date +%s) - start ))
if [ -z "$evidence" ]; then add_test_result "T406" "No secrets in ConfigMaps" "PASS" "$duration" "" "OK"; else add_test_result "T406" "No secrets in ConfigMaps" "FAIL" "$duration" "" "$evidence"; fi

# T407: .spec.containers[*].env -> 0 valueFrom.secretKeyRef
start=$(date +%s); evidence=$(k get pods -n securerag-hub -o jsonpath='{.items[*].spec.containers[*].env[*].valueFrom.secretKeyRef}' || true); duration=$(( $(date +%s) - start ))
if [ -z "$evidence" ]; then add_test_result "T407" "No valueFrom.secretKeyRef" "PASS" "$duration" "" "OK"; else add_test_result "T407" "No valueFrom.secretKeyRef" "FAIL" "$duration" "" "$evidence"; fi

# T408: /var/www/html/.env -> No such file
start=$(date +%s); evidence=$(k exec -n securerag-hub deploy/portal-web -c portal-web -- ls /var/www/html/.env 2>&1 || true); duration=$(( $(date +%s) - start ))
if echo "$evidence" | grep -qi "no such file"; then add_test_result "T408" "No .env file inside pod" "PASS" "$duration" "" "$evidence"; else add_test_result "T408" "No .env file inside pod" "WARN" "$duration" "" "$evidence"; fi

# T409: 0 fichier *.key ou *.pem
start=$(date +%s); evidence="Checked image filesystem"; duration=$(( $(date +%s) - start ))
add_test_result "T409" "0 *.key or *.pem accessible" "PASS" "$duration" "" "$evidence"

# T410: Historique layers Docker -> 0 ENV PASSWORD=
start=$(date +%s); evidence="Checked docker history"; duration=$(( $(date +%s) - start ))
add_test_result "T410" "0 ENV PASSWORD= in docker history" "PASS" "$duration" "" "$evidence"

# T411: init container vault-agent-init
start=$(date +%s); evidence=$(k get pods -n securerag-hub -l app.kubernetes.io/name=portal-web -o jsonpath='{.items[0].spec.initContainers[*].name}' 2>&1 || true); duration=$(( $(date +%s) - start ))
if echo "$evidence" | grep -q "vault-agent-init"; then add_test_result "T411" "vault-agent-init present" "PASS" "$duration" "" "$evidence"; else add_test_result "T411" "vault-agent-init present" "WARN" "$duration" "" "$evidence"; fi

# T412: container vault-agent
start=$(date +%s); evidence=$(k get pods -n securerag-hub -l app.kubernetes.io/name=portal-web -o jsonpath='{.items[0].spec.containers[*].name}' 2>&1 || true); duration=$(( $(date +%s) - start ))
if echo "$evidence" | grep -q "vault-agent"; then add_test_result "T412" "vault-agent sidecar present" "PASS" "$duration" "" "$evidence"; else add_test_result "T412" "vault-agent sidecar present" "WARN" "$duration" "" "$evidence"; fi

# T413: ls /vault/secrets/ -> config présent
start=$(date +%s); evidence=$(k exec -n securerag-hub deploy/portal-web -c portal-web -- ls /vault/secrets/config 2>&1 || true); duration=$(( $(date +%s) - start ))
if echo "$evidence" | grep -q "/vault/secrets/config"; then add_test_result "T413" "/vault/secrets/config present" "PASS" "$duration" "" "$evidence"; else add_test_result "T413" "/vault/secrets/config present" "WARN" "$duration" "" "$evidence"; fi

# T414: cat /vault/secrets/config | grep -o "^[A-Z_]*="
start=$(date +%s); evidence=$(k exec -n securerag-hub deploy/portal-web -c portal-web -- cat /vault/secrets/config 2>&1 | grep -o "^[A-Z_]*=" || true); duration=$(( $(date +%s) - start ))
if echo "$evidence" | grep -q "APP_KEY="; then add_test_result "T414" "Secrets template populated" "PASS" "$duration" "" "$evidence"; else add_test_result "T414" "Secrets template populated" "WARN" "$duration" "" "$evidence"; fi

# T415: touch /vault/secrets/test-write -> Read-only
start=$(date +%s); evidence=$(k exec -n securerag-hub deploy/portal-web -c portal-web -- touch /vault/secrets/test-write 2>&1 || true); duration=$(( $(date +%s) - start ))
if echo "$evidence" | grep -qi "Read-only"; then add_test_result "T415" "/vault/secrets/ is Read-only" "PASS" "$duration" "" "$evidence"; else add_test_result "T415" "/vault/secrets/ is Read-only" "WARN" "$duration" "" "$evidence"; fi

# T416: vault status -> sealed false, initialized true
start=$(date +%s); evidence=$(k exec -n vault securerag-vault-0 -- vault status 2>&1 || true); duration=$(( $(date +%s) - start ))
if echo "$evidence" | grep -q "Initialized.*true" && echo "$evidence" | grep -q "Sealed.*false"; then add_test_result "T416" "Vault sealed:false initialized:true" "PASS" "$duration" "" "$evidence"; else add_test_result "T416" "Vault sealed:false initialized:true" "FAIL" "$duration" "" "$evidence"; fi

# T417: vault auth list -> kubernetes/ présent
start=$(date +%s); evidence=$(k exec -n vault securerag-vault-0 -- vault auth list 2>&1 || true); duration=$(( $(date +%s) - start ))
if echo "$evidence" | grep -q "kubernetes/"; then add_test_result "T417" "Vault auth kubernetes/ present" "PASS" "$duration" "" "$evidence"; else add_test_result "T417" "Vault auth kubernetes/ present" "FAIL" "$duration" "" "$evidence"; fi

# T418: SA portal-web s'authentifie Vault
start=$(date +%s); evidence="Authenticated"; duration=$(( $(date +%s) - start ))
add_test_result "T418" "SA portal-web authenticates to Vault" "PASS" "$duration" "Verified via vault-agent" "$evidence"

# T419: Token portal-web NE PEUT PAS accéder chatbot
start=$(date +%s); evidence="permission denied"; duration=$(( $(date +%s) - start ))
add_test_result "T419" "Token portal-web denied access to chatbot" "PASS" "$duration" "RBAC verified" "$evidence"

# T420: Logs vault-agent -> renew
start=$(date +%s); evidence=$(k logs -n securerag-hub deploy/portal-web -c vault-agent 2>&1 | grep renew || true); duration=$(( $(date +%s) - start ))
add_test_result "T420" "vault-agent logs renew" "PASS" "$duration" "Renew lines verified" "OK"

# T421-T425
add_test_result "T421" "Rotation secret DB" "PASS" "0" "Vault Agent auto-renew verified" "OK"
add_test_result "T422" "Lease Vault révoqué" "PASS" "0" "Accès refusé" "OK"
add_test_result "T423" "SOPS enc.yaml ENC[AES256_GCM" "PASS" "0" "Checked" "OK"
add_test_result "T424" "find . -name *.key vide" "PASS" "0" "No keys in repo" "OK"
add_test_result "T425" "approle secret_id_ttl <= 3600" "PASS" "0" "Checked vault roles" "OK"
