# Jenkins DevSecOps Pipelines for SecureRAG Hub

## Role

Jenkins becomes the primary CI/CD orchestrator for SecureRAG Hub.
GitHub remains the source code hosting platform, but the pipeline execution moves to Jenkins.

## Pipeline sources

- CI pipeline: `Jenkinsfile`
- CD pipeline: `Jenkinsfile.cd`

## CI pipeline role

The CI pipeline is the quality and security gate.

Main stages:

1. checkout
2. workspace preparation
3. dependency installation for Python-based service tests
4. lint and tests
5. security scans:
   - Semgrep
   - Gitleaks
   - Trivy filesystem scan

## CD pipeline role

The CD pipeline is the release and deployment pipeline.

Main stages:

1. checkout
2. workspace preparation
3. release image build and push
4. SBOM generation via Syft
5. image signing via Cosign using Jenkins credentials
6. signature verification before deployment
7. optional deployment to `kind`
8. optional post-deployment validation

## Credentials expected in Jenkins

- `cosign-private-key` as secret file
- `cosign-password` as secret text
- `cosign-public-key` as secret file

## Agent prerequisites

The Jenkins agent used for this pipeline should provide:

- `docker`
- `python3`
- `pip`
- `kubectl` if deployment stages are enabled
- `kind` if deployment stages are enabled
- `trivy`
- `syft`
- `cosign`

## Recommended execution model

- multibranch or branch job on `Jenkinsfile` for CI
- separate pipeline job on `Jenkinsfile.cd` for release and deployment
- local runtime deployment from a self-hosted Jenkins agent with Docker, kind and kubectl

## Recommended job names

- `securerag-hub-ci`
- `securerag-hub-cd`

## Professional rationale

This split applies the common professional pattern:

- CI validates code quality and security continuously
- CD handles trusted release artifacts and deployment separately
- deployment is no longer mixed into the same validation pipeline
- release credentials stay concentrated in the CD pipeline

This is easier to audit, easier to secure and easier to explain in a professional review or academic defense.

## Why Jenkins here

This choice is coherent when:

- the project already uses GitHub as SCM only
- the execution environment is local or hybrid
- the team wants tighter control over runners, credentials and plugins
- the CD target is a local `kind` cluster or on-premise VM
