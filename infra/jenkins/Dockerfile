# [SEC-01]
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
ARG K6_VERSION=v0.56.0

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

# Enable Xdebug for code coverage — robust path detection
RUN PHP_VERSION=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;') && \
    PHP_INI_DIR=$(php -r 'echo PHP_CONFIG_FILE_SCAN_DIR;' 2>/dev/null || echo "/etc/php/${PHP_VERSION}/cli/conf.d") && \
    mkdir -p "${PHP_INI_DIR}" && \
    printf "zend_extension=xdebug.so\nxdebug.mode=coverage\nxdebug.start_with_request=no\nxdebug.output_dir=/tmp\n" > "${PHP_INI_DIR}/20-xdebug.ini" && \
    echo "[BUILD] Xdebug INI written to ${PHP_INI_DIR}/20-xdebug.ini" && \
    php -m 2>/dev/null | grep -i xdebug && echo "[BUILD] Xdebug module detected" || echo "[BUILD] WARNING: Xdebug NOT detected" && \
    php --ri xdebug 2>/dev/null | head -5 || true

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
      "https://github.com/sigstore/cosign/releases/download/v3.1.1/cosign-linux-${OCI_ARCH}"; \
    echo "ae1ecd212663f3693ad9edf8b1a183900c9a52d3155ba6e354237f9a0f6463fc  /usr/local/bin/cosign" | sha256sum -c -; \
    chmod +x /usr/local/bin/cosign; \
    cosign version; \
    curl -fsSLo /tmp/syft.tar.gz \
      "https://github.com/anchore/syft/releases/download/v1.45.1/syft_1.45.1_linux_${SYFT_ARCH}.tar.gz"; \
    echo "20c84195e24927f50a3b2269946be51f4c4abc9d2f145fee7388b4199149f716  /tmp/syft.tar.gz" | sha256sum -c -; \
    tar -xzf /tmp/syft.tar.gz -C /tmp syft; \
    install -m 0755 /tmp/syft /usr/local/bin/syft; \
    rm -f /tmp/syft.tar.gz /tmp/syft; \
    syft version; \
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
    rm -f /tmp/sonar-scanner.zip; \
    curl -fsSLo /tmp/k6.tar.gz \
      "https://github.com/grafana/k6/releases/download/${K6_VERSION}/k6-${K6_VERSION}-linux-${OCI_ARCH}.tar.gz"; \
    tar -xzf /tmp/k6.tar.gz -C /tmp; \
    install -m 0755 "/tmp/k6-${K6_VERSION}-linux-${OCI_ARCH}/k6" /usr/local/bin/k6; \
    rm -rf /tmp/k6.tar.gz "/tmp/k6-${K6_VERSION}-linux-${OCI_ARCH}"

ENV PIP_DISABLE_PIP_VERSION_CHECK=1

RUN python3 -m venv /opt/checkov-venv && \
    /opt/checkov-venv/bin/pip install --no-cache-dir checkov && \
    ln -s /opt/checkov-venv/bin/checkov /usr/local/bin/checkov

COPY entrypoint.sh /usr/local/bin/securerag-jenkins-entrypoint.sh
RUN chmod +x /usr/local/bin/securerag-jenkins-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/securerag-jenkins-entrypoint.sh"]

USER jenkins
