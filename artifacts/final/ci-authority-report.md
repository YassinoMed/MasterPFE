# CI Authority Report - SecureRAG Hub

- Generated at UTC: `2026-04-25T20:08:07Z`
- Status: `TERMINÉ`

## Decision

Jenkins is the official CI/CD authority. GitHub Actions workflows are retained only as manual legacy mirrors and must not be used as final evidence when Jenkins or shell artifacts exist.

| Workflow | Status | Detail |
|---|---:|---|
| `.github/workflows/build-sign.yml` | TERMINÉ | manual `workflow_dispatch` only |
| `.github/workflows/ci-pr.yml` | TERMINÉ | manual `workflow_dispatch` only |
| `.github/workflows/deploy-kind-dev.yml` | TERMINÉ | manual `workflow_dispatch` only |
| `.github/workflows/validate-postdeploy.yml` | TERMINÉ | manual `workflow_dispatch` only |

## Jenkins authority evidence

- `Jenkinsfile`
- `Jenkinsfile.cd`
- `infra/jenkins/casc/jenkins.yaml`
- `infra/jenkins/jobs/`
- `docs/runbooks/jenkins.md`
