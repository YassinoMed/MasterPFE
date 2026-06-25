# [SEC-01]
# docker-agent — Trivy + Grype + Syft + Cosign + Docker Build
FROM docker:27-dind

RUN apk add --no-cache curl bash jq python3

# Trivy
ARG TRIVY_VERSION=0.69.3
RUN curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | \
    sh -s -- -b /usr/local/bin v${TRIVY_VERSION}

# Syft
ARG SYFT_VERSION=1.45.1
ARG SYFT_SHA256="20c84195e24927f50a3b2269946be51f4c4abc9d2f145fee7388b4199149f716"
RUN curl -sSLo syft.tar.gz "https://github.com/anchore/syft/releases/download/v${SYFT_VERSION}/syft_${SYFT_VERSION}_linux_amd64.tar.gz" \
    && echo "${SYFT_SHA256}  syft.tar.gz" | sha256sum -c - \
    && tar -xzf syft.tar.gz -C /usr/local/bin syft \
    && rm syft.tar.gz \
    && syft version

# Grype
RUN curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | \
    sh -s -- -b /usr/local/bin

# Cosign
ARG COSIGN_VERSION=v3.1.1
ARG COSIGN_SHA256="ae1ecd212663f3693ad9edf8b1a183900c9a52d3155ba6e354237f9a0f6463fc"
RUN curl -sSLo /usr/local/bin/cosign "https://github.com/sigstore/cosign/releases/download/v${COSIGN_VERSION}/cosign-linux-amd64" \
    && echo "${COSIGN_SHA256}  /usr/local/bin/cosign" | sha256sum -c - \
    && chmod +x /usr/local/bin/cosign \
    && cosign version

WORKDIR /workspace
VOLUME /var/lib/docker
ENTRYPOINT ["/bin/sh", "-c"]
