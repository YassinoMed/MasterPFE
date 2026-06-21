# k8s-agent — Checkov + kube-score + Kyverno CLI + kubectl
FROM alpine:3.20

RUN apk add --no-cache curl bash python3 py3-pip kubectl

# Checkov
RUN python3 -m venv /opt/checkov-venv && \
    /opt/checkov-venv/bin/pip install --no-cache-dir checkov && \
    ln -s /opt/checkov-venv/bin/checkov /usr/local/bin/checkov

# kube-score
ARG KUBE_SCORE_VERSION=1.18.0
RUN curl -sSLo /usr/local/bin/kube-score \
    "https://github.com/zegl/kube-score/releases/download/v${KUBE_SCORE_VERSION}/kube-score_${KUBE_SCORE_VERSION}_linux_amd64" \
    && chmod +x /usr/local/bin/kube-score

# Kyverno CLI
ARG KYVERNO_VERSION=v1.16.2
RUN curl -sSLo /tmp/kyverno.tar.gz \
    "https://github.com/kyverno/kyverno/releases/download/${KYVERNO_VERSION}/kyverno-cli_${KYVERNO_VERSION}_linux_x86_64.tar.gz" \
    && tar -xzf /tmp/kyverno.tar.gz -C /tmp && mv /tmp/kyverno /usr/local/bin/ \
    && chmod +x /usr/local/bin/kyverno && rm /tmp/kyverno.tar.gz

WORKDIR /workspace
ENTRYPOINT ["/bin/sh", "-c"]
