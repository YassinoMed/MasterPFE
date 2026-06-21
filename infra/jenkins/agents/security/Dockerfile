# security-agent — Semgrep + Gitleaks
FROM python:3.12-alpine

RUN pip install --no-cache-dir semgrep==1.156.0

# Gitleaks binary
ARG GITLEAKS_VERSION=8.30.1
RUN wget -qO /usr/local/bin/gitleaks \
    "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_amd64.tar.gz" \
    && tar -xzf /usr/local/bin/gitleaks -C /usr/local/bin 2>/dev/null || true \
    && chmod +x /usr/local/bin/gitleaks 2>/dev/null || true

# Alternative: install gitleaks via go
RUN if [ ! -f /usr/local/bin/gitleaks ]; then \
      apk add --no-cache go && \
      go install github.com/gitleaks/gitleaks/v8@v${GITLEAKS_VERSION} && \
      cp /root/go/bin/gitleaks /usr/local/bin/; \
    fi

WORKDIR /workspace
ENTRYPOINT ["/bin/sh", "-c"]
