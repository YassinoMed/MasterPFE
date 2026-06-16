# deploy-agent — kubectl + Helm + ArgoCD CLI
FROM alpine:3.20

RUN apk add --no-cache curl bash kubectl helm

# ArgoCD CLI
ARG ARGOCD_VERSION=v2.14.0
RUN curl -sSLo /usr/local/bin/argocd \
    "https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-amd64" \
    && chmod +x /usr/local/bin/argocd

WORKDIR /workspace
ENTRYPOINT ["/bin/sh", "-c"]
