# Jenkins GitHub Webhook Runbook - SecureRAG Hub

## Objective

Trigger the official Jenkins CI job automatically when code is pushed to GitHub.

## Official CI job

- Jenkins job: `securerag-hub-ci`
- Pipeline file: `Jenkinsfile`
- Repository: `https://github.com/YassinoMed/MasterPFE.git`
- Branch: `main`

## Jenkins trigger strategy

The CI job uses two triggers:

- GitHub push webhook for immediate builds.
- SCM polling every 5 minutes as a cloud fallback.

This keeps the CI automated even if the GitHub webhook cannot reach the Jenkins container during a demo.

## Jenkins URL

Set the Jenkins public URL in `infra/jenkins/docker-compose.yml`:

```yaml
JENKINS_URL: http://141.95.135.130:8085/
```

Then restart Jenkins:

```bash
cd /opt/MasterPFE
docker compose -f infra/jenkins/docker-compose.yml up -d --build
bash scripts/jenkins/wait-for-jenkins.sh
```

## GitHub webhook configuration

In GitHub:

1. Open the repository settings.
2. Go to `Webhooks`.
3. Click `Add webhook`.
4. Use this payload URL:

```text
http://141.95.135.130:8085/github-webhook/
```

5. Set `Content type` to:

```text
application/json
```

6. Select:

```text
Just the push event
```

7. Save the webhook.

## Cloud firewall

The Jenkins web port must be reachable from GitHub:

```bash
sudo ss -lntp | grep 8085
curl -I http://141.95.135.130:8085/login
```

Expected result:

```text
HTTP/1.1 200 OK
```

or:

```text
HTTP/1.1 403 Forbidden
```

Both prove that Jenkins is reachable. A browser login page is expected for normal users.

## Test the automation

Push a small commit:

```bash
cd /opt/MasterPFE
git pull origin main
git status
git commit --allow-empty -m "ci: test Jenkins webhook"
git push origin main
```

Expected result:

- GitHub webhook delivery returns `200`.
- Jenkins starts `securerag-hub-ci`.
- The CI pipeline runs tests, coverage, Semgrep, Gitleaks and Trivy.

## Prove that Jenkins consumed the pushed commit

After the push, generate a factual Jenkins proof:

```bash
JENKINS_URL=http://141.95.135.130:8085 \
JENKINS_USER=admin \
JENKINS_TOKEN=<jenkins-api-token> \
make jenkins-ci-push-proof
```

Expected evidence:

```text
artifacts/jenkins/ci-push-trigger-proof.md
artifacts/jenkins/ci-push-last-build.json
```

The proof is considered complete only if the report contains:

```text
Expected commit in Jenkins last build | OK
```

If Jenkins returns `403`, create an API token from the Jenkins user profile and rerun the command with `JENKINS_USER` and `JENKINS_TOKEN`.

## If the webhook fails

If GitHub cannot reach Jenkins:

- keep the SCM polling fallback enabled;
- Jenkins will still run within about 5 minutes;
- use the `/workspace` fallback pipeline only for cloud demos with unstable GitHub checkout.

Useful diagnostic commands:

```bash
docker logs securerag-jenkins --tail=100
docker exec securerag-jenkins git ls-remote https://github.com/YassinoMed/MasterPFE.git
curl -I http://141.95.135.130:8085/login
```
