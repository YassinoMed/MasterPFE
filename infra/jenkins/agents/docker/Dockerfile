# docker-agent — Trivy + Grype + Syft + Cosign + Docker Build
FROM docker:27-dind

RUN apk add --no-cache curl bash jq python3

# Trivy
ARG TRIVY_VERSION=0.69.3
RUN curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | \
    sh -s -- -b /usr/local/bin v${TRIVY_VERSION}

# Syft
ARG SYFT_VERSION=1.42.3
RUN curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | \
    sh -s -- -b /usr/local/bin v${SYFT_VERSION}

# Grype
RUN curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | \
    sh -s -- -b /usr/local/bin

# Cosign
ARG COSIGN_VERSION=v2.5.3
RUN curl -sSLo /usr/local/bin/cosign \
    "https://github.com/sigstore/cosign/releases/download/${COSIGN_VERSION}/cosign-linux-amd64" \
    && chmod +x /usr/local/bin/cosign && cosign version

WORKDIR /workspace
VOLUME /var/lib/docker
ENTRYPOINT ["/bin/sh", "-c"]
