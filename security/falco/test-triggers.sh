#!/usr/bin/env bash
# Harmless commands to verify Falco rules fire as expected.
# Run inside an EPHEMERAL pod in `securerag-hub` only — never in prod.
#
# Usage (operator manually approves first):
#   kubectl -n securerag-hub run falco-test --rm -it --restart=Never \
#     --image=alpine:3.20 -- /bin/sh
#   # then paste the snippets below.
#
# Each block prints the EXPECTED rule name. Inspect Falco logs:
#   kubectl -n falco logs -l app.kubernetes.io/name=falco --tail=200 -f \
#     | grep -E "SecureRAG"

set -euo pipefail

cat <<'EOF'
# 1. EXPECTED: "SecureRAG Shell in Container"
sh -c 'echo trigger; sleep 1'

# 2. EXPECTED: "SecureRAG Package Manager in Container"
apk --version || true

# 3. EXPECTED: "SecureRAG Sensitive File Read"
cat /var/run/secrets/kubernetes.io/serviceaccount/token >/dev/null || true

# 4. EXPECTED: "SecureRAG Outbound Unexpected Port (Refined)"
# (port 31337 is not on the allow-list — this should ATTEMPT a connection)
nc -zw2 1.1.1.1 31337 || true

# 5. EXPECTED: "SecureRAG Write Below Sensitive Path"
echo test > /etc/falco-test-marker || true
rm -f /etc/falco-test-marker || true

# 6. EXPECTED: "SecureRAG User Account Mutation"
adduser -D testuser 2>/dev/null || useradd testuser 2>/dev/null || true
EOF

echo
echo "[INFO] Snippets printed. Execute them inside an ephemeral pod and"
echo "[INFO] tail Falco logs to verify each rule fires as expected."
