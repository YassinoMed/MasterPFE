FROM jenkins/jenkins:lts-jdk21

USER root

ARG TARGETARCH
ARG KUBECTL_VERSION=v1.33.1
ARG KIND_VERSION=v0.29.0
ARG COSIGN_VERSION=v2.5.3
ARG SYFT_VERSION=v1.42.3
ARG TRIVY_VERSION=0.69.3
ARG KUBE_SCORE_VERSION=1.18.0
ARG SONAR_SCANNER_VERSION=5.0.1.3006
ARG KYVERNO_VERSION=v1.16.2

# Install gnupg first (not present in base image), then add Docker official repo
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates curl gnupg && \
    install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/debian/gpg \
      | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    chmod a+r /etc/apt/keyrings/docker.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/debian \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
      > /etc/apt/sources.list.d/docker.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
      docker-ce-cli \
      docker-buildx-plugin \
      docker-compose-plugin \
      git \
      jq \
      make \
      composer \
      nodejs \
      npm \
      php-cli \
      php-curl \
      php-intl \
      php-mbstring \
      php-sqlite3 \
      php-xml \
      php-zip \
      php-xdebug \
      python3 \
      python3-pip \
      python3-yaml \
      python3-venv \
      ruby \
      socat \
      unzip && \
    rm -rf /var/lib/apt/lists/*

# Enable Xdebug for code coverage
RUN echo "zend_extension=xdebug.so" > /etc/php/8.2/cli/conf.d/20-xdebug.ini && \
    echo "xdebug.mode=coverage" >> /etc/php/8.2/cli/conf.d/20-xdebug.ini

COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) KUBE_ARCH=amd64; OCI_ARCH=amd64; SYFT_ARCH=amd64; TRIVY_ARCH=64bit; KS_ARCH=amd64; KYVERNO_ARCH=x86_64 ;; \
      arm64) KUBE_ARCH=arm64; OCI_ARCH=arm64; SYFT_ARCH=arm64; TRIVY_ARCH=ARM64; KS_ARCH=arm64; KYVERNO_ARCH=arm64 ;; \
      *) echo "Unsupported TARGETARCH=${TARGETARCH}"; exit 1 ;; \
    esac; \
    curl -fsSLo /usr/local/bin/kubectl \
      "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${KUBE_ARCH}/kubectl"; \
    chmod +x /usr/local/bin/kubectl; \
    curl -fsSLo /usr/local/bin/kind \
      "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-${OCI_ARCH}"; \
    chmod +x /usr/local/bin/kind; \
    curl -fsSLo /usr/local/bin/cosign \
      "https://github.com/sigstore/cosign/releases/download/${COSIGN_VERSION}/cosign-linux-${OCI_ARCH}"; \
    chmod +x /usr/local/bin/cosign; \
    curl -fsSLo /tmp/syft.tar.gz \
      "https://github.com/anchore/syft/releases/download/${SYFT_VERSION}/syft_${SYFT_VERSION#v}_linux_${SYFT_ARCH}.tar.gz"; \
    tar -xzf /tmp/syft.tar.gz -C /tmp syft; \
    install -m 0755 /tmp/syft /usr/local/bin/syft; \
    rm -f /tmp/syft.tar.gz /tmp/syft; \
    curl -fsSLo /tmp/trivy.tar.gz \
      "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-${TRIVY_ARCH}.tar.gz"; \
    tar -xzf /tmp/trivy.tar.gz -C /tmp trivy; \
    install -m 0755 /tmp/trivy /usr/local/bin/trivy; \
    rm -f /tmp/trivy.tar.gz /tmp/trivy; \
    curl -fsSLo /tmp/kube-score.tar.gz \
      "https://github.com/zegl/kube-score/releases/download/v${KUBE_SCORE_VERSION}/kube-score_${KUBE_SCORE_VERSION}_linux_${KS_ARCH}.tar.gz"; \
    tar -xzf /tmp/kube-score.tar.gz -C /tmp kube-score; \
    install -m 0755 /tmp/kube-score /usr/local/bin/kube-score; \
    rm -f /tmp/kube-score.tar.gz /tmp/kube-score; \
    curl -fsSLo /tmp/kyverno.tar.gz \
      "https://github.com/kyverno/kyverno/releases/download/${KYVERNO_VERSION}/kyverno-cli_${KYVERNO_VERSION}_linux_${KYVERNO_ARCH}.tar.gz"; \
    tar -xzf /tmp/kyverno.tar.gz -C /tmp kyverno; \
    install -m 0755 /tmp/kyverno /usr/local/bin/kyverno; \
    rm -f /tmp/kyverno.tar.gz /tmp/kyverno; \
    curl -fsSLo /tmp/sonar-scanner.zip \
      "https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${SONAR_SCANNER_VERSION}-linux.zip"; \
    unzip -q /tmp/sonar-scanner.zip -d /opt; \
    ln -sf "/opt/sonar-scanner-${SONAR_SCANNER_VERSION}-linux/bin/sonar-scanner" /usr/local/bin/sonar-scanner; \
    rm -f /tmp/sonar-scanner.zip

ENV PIP_DISABLE_PIP_VERSION_CHECK=1

RUN python3 -m venv /opt/checkov-venv && \
    /opt/checkov-venv/bin/pip install --no-cache-dir checkov && \
    ln -s /opt/checkov-venv/bin/checkov /usr/local/bin/checkov

COPY entrypoint.sh /usr/local/bin/securerag-jenkins-entrypoint.sh
RUN chmod +x /usr/local/bin/securerag-jenkins-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/securerag-jenkins-entrypoint.sh"]

USER jenkins
