# zap-agent — OWASP ZAP
FROM ghcr.io/zaproxy/zaproxy:2.15.0

USER root
RUN apt-get update && apt-get install -y curl jq python3 && rm -rf /var/lib/apt/lists/*
USER zap

WORKDIR /zap
ENTRYPOINT ["/bin/sh", "-c"]
