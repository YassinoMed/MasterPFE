# Legacy Runtime Overlay Status

This directory intentionally does not provide a deployable `kustomization.yaml`.

The production and demo runtimes are Laravel-first and are rendered from:

- `infra/k8s/overlays/demo`
- `infra/k8s/overlays/dev`
- `infra/k8s/overlays/production`

Historical runtime folders under `infra/k8s/base` are not included in the official Kustomize graph because their corresponding application sources are not buildable in the current repository state. Keeping this marker avoids silently reintroducing non-production workloads into release, HA, or security evidence.

To inspect or clean a cluster that still contains legacy objects, use:

```bash
make production-cleanup-plan
CONFIRM_CLEANUP=YES make production-cleanup
```

Do not add a deployable legacy overlay unless the source code, Dockerfiles, NetworkPolicies, probes, resource limits, securityContext, SBOM, image signatures and runtime evidence are restored together.
