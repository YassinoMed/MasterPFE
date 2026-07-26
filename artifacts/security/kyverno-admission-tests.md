# Kyverno admission tests — SecureRAG Hub

- Generated UTC: `2026-07-25T20:39:54Z`
- Status: `PARTIEL`
- Pass: `5`  Fail: `1`

## PASS

- REJECT/hostpath-volume
- REJECT/privileged-container
- REJECT/missing-resources
- REJECT/loadbalancer-service
- REJECT/cleartext-secret

## FAIL

- ADMIT/compliant-pod — expected admit, was rejected
