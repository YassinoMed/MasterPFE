# Jenkins Cloud Fallback Runbook - SecureRAG Hub

## Objective

Document the safe fallback mode used when Jenkins runs in a local or cloud Docker container and cannot reliably clone GitHub from inside the container.

## Official position

- Jenkins remains the official CI/CD authority.
- GitHub remains the official source control system.
- GitHub Actions remain legacy workflows unless explicitly reactivated.
- The fallback mode is an operational tolerance for local or soutenance demonstrations.

## Nominal mode

The nominal Jenkins setup is:

- job type: Pipeline
- definition: Pipeline script from SCM
- repository: `https://github.com/YassinoMed/MasterPFE.git`
- CI script path: `Jenkinsfile`
- CD script path: `Jenkinsfile.cd`
- branch: `main`

## Typical cloud symptoms

Use this runbook when Jenkins shows one of these symptoms:

- `Failed to connect to github.com port 443`
- `Error fetching remote repo origin`
- DNS or egress timeout from the Jenkins container
- SCM checkout is too slow or unstable for a live demo

## Fallback mode

The project root is mounted inside Jenkins as:

```text
/workspace
```

In fallback mode, the Jenkins job uses an inline Pipeline script and executes commands from `/workspace`.

This keeps the demo stable while preserving Jenkins as the execution authority.

## Kubernetes access from Jenkins

For kind clusters running on the same Docker host, Jenkins must be connected to the `kind` Docker network and must use a kubeconfig whose API server points to the kind control-plane container.

Recommended repair command:

```bash
bash scripts/jenkins/fix-cloud-kind-access.sh
```

Expected result:

```text
Jenkins can now reach the kind cluster.
```

## Validation commands

From the Docker host:

```bash
docker compose -f infra/jenkins/docker-compose.yml ps
docker exec securerag-jenkins ls /workspace
docker exec securerag-jenkins bash -lc 'KUBECONFIG=/var/jenkins_home/.kube/config kubectl get pods -n securerag-hub'
curl -I http://localhost:8085/login
```

Expected result:

- Jenkins container is running and healthy.
- `/workspace` contains the repository.
- Jenkins can list the `securerag-hub` pods.
- Jenkins login page returns HTTP 200 or 403 if anonymous access is blocked.

## When to use fallback

Use fallback for:

- cloud VM demonstrations;
- unstable network egress from Jenkins;
- live soutenance sessions where repeatability is more important than SCM checkout proof.

## When to return to nominal mode

Return to SCM mode when:

- Jenkins can reach GitHub from inside the container;
- SCM credentials are configured;
- checkout of `Jenkinsfile` and `Jenkinsfile.cd` is reliable;
- the demo does not depend on cloud network variability.

## Soutenance wording

Use this wording:

```text
Jenkins is the official CI/CD authority. In the cloud demo, the repository is mounted as /workspace to avoid network variability during GitHub checkout from the container. This is an operational fallback; the canonical pipeline definitions remain Jenkinsfile and Jenkinsfile.cd in GitHub.
```
