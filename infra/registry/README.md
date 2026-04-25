# Cluster-Reachable Registry

This registry layer removes the production-like limitation where workloads only
reference `localhost:5001`. The demo registry can stay available, but expert
runtime proofs should use a registry name resolvable and pullable from kind
nodes and Pods.

Recommended local topology:

| Side | Endpoint |
|---|---|
| Host and Jenkins | `127.0.0.1:5002` |
| Kubernetes nodes and Pods | `securerag-registry:5000` |

Required proof:

- `artifacts/validation/cluster-registry-setup.md`
- `artifacts/validation/cluster-registry-report.md`
- `artifacts/release/promotion-digests-cluster.txt`

Commands:

```bash
make cluster-registry-setup
REGISTRY_HOST_SIDE=127.0.0.1:5002 \
REGISTRY_CLUSTER_HOST=securerag-registry:5000 \
IMAGE_TAG=production \
TARGET_IMAGE_TAG=release-prod \
make cluster-registry-proof
```

Production rule:

- deploy images by immutable digest;
- keep `localhost:5001` only for demo compatibility;
- use a TLS registry for non-kind production clusters.
