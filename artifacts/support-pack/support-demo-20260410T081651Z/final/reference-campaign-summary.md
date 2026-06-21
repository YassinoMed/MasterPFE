# SecureRAG Hub Reference Campaign

- Timestamp (UTC): 2026-04-10T08:16:51Z
- Registry: `localhost:5001`
- Image prefix: `securerag-hub`
- Source tag: `demo`
- Target tag: `demo-release`
- Overlay: `infra/k8s/overlays/demo`
- Mode label: `demo`

- Campaign mode: `dry-run`

- Promotion strategy: `digest`

## Executed steps
- verify source signatures: SKIPPED (dry-run)
- promote images without rebuild: SKIPPED (dry-run)
- deploy verified images: SKIPPED (dry-run)
- validation suite: SKIPPED (dry-run)
- runtime evidence collection: SKIPPED (dry-run)

## Produced artifacts
- `reference-campaign-commands.sh`
- `image-selection.txt`
- `rendered-overlay.yaml`
- `cluster-context.txt`

## Environment-dependent notes
- This run was intentionally executed in dry-run mode.
- No signature verification, promotion, deployment, or validation command was executed.
