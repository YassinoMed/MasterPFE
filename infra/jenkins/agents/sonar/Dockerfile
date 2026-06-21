# sonar-agent — Sonar Scanner
FROM sonarsource/sonar-scanner-cli:5.0.1

USER root
RUN apk add --no-cache curl jq bash
USER sonar

WORKDIR /usr/src
ENTRYPOINT ["/bin/sh", "-c"]
