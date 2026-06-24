# Kyverno admission tests — SecureRAG Hub

- Generated UTC: `2026-06-23T06:02:18Z`
- Status: `PARTIEL`
- Pass: `1`  Fail: `5`

## PASS

- ADMIT/compliant-pod

## FAIL

- REJECT/hostpath-volume — expected reject, was admitted
- REJECT/privileged-container — expected reject, was admitted
- REJECT/missing-resources — expected reject, was admitted
- REJECT/loadbalancer-service — expected reject, was admitted
- REJECT/cleartext-secret — expected reject, was admitted
