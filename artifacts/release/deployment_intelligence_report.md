# Rapport de Validation de Déploiement - Deployment Intelligence Agent
**Deployment Risk Score** : `100.0/100`
**Nombre d'anomalies de configuration** : 110

## 1. Anomalies Détectées
### [Runs as Root] - Deployment/backstage/container/backstage
* **Fichier** : `/root/MasterPFE/infra/k8s/backstage/deployment.yaml`
* **Sévérité** : `HIGH`
* **Description** : Container is allowed to run as root.

### [Writable Root Filesystem] - Deployment/backstage/container/backstage
* **Fichier** : `/root/MasterPFE/infra/k8s/backstage/deployment.yaml`
* **Sévérité** : `MEDIUM`
* **Description** : Root filesystem is writable. Risk of persistence on compromise.

### [Runs as Root] - Deployment/spire-server/container/spire-server
* **Fichier** : `/root/MasterPFE/infra/k8s/spiffe/deployment.yaml`
* **Sévérité** : `HIGH`
* **Description** : Container is allowed to run as root.

### [Writable Root Filesystem] - Deployment/spire-server/container/spire-server
* **Fichier** : `/root/MasterPFE/infra/k8s/spiffe/deployment.yaml`
* **Sévérité** : `MEDIUM`
* **Description** : Root filesystem is writable. Risk of persistence on compromise.

### [Runs as Root] - Deployment/spire-server/container/spire-controller-manager
* **Fichier** : `/root/MasterPFE/infra/k8s/spiffe/deployment.yaml`
* **Sévérité** : `HIGH`
* **Description** : Container is allowed to run as root.

### [Writable Root Filesystem] - Deployment/spire-server/container/spire-controller-manager
* **Fichier** : `/root/MasterPFE/infra/k8s/spiffe/deployment.yaml`
* **Sévérité** : `MEDIUM`
* **Description** : Root filesystem is writable. Risk of persistence on compromise.

### [hostPath Volume Mounted] - DaemonSet/spire-agent
* **Fichier** : `/root/MasterPFE/infra/k8s/spiffe/deployment.yaml`
* **Sévérité** : `CRITICAL`
* **Description** : Volume 'spire-agent-socket' mounts a host path. Risk of node compromise.

### [Runs as Root] - DaemonSet/spire-agent/container/spire-agent
* **Fichier** : `/root/MasterPFE/infra/k8s/spiffe/deployment.yaml`
* **Sévérité** : `HIGH`
* **Description** : Container is allowed to run as root.

### [Writable Root Filesystem] - DaemonSet/spire-agent/container/spire-agent
* **Fichier** : `/root/MasterPFE/infra/k8s/spiffe/deployment.yaml`
* **Sévérité** : `MEDIUM`
* **Description** : Root filesystem is writable. Risk of persistence on compromise.

### [Runs as Root] - Deployment/ollama/container/ollama
* **Fichier** : `/root/MasterPFE/infra/k8s/aiops/deployment.yaml`
* **Sévérité** : `HIGH`
* **Description** : Container is allowed to run as root.

### [Writable Root Filesystem] - Deployment/ollama/container/ollama
* **Fichier** : `/root/MasterPFE/infra/k8s/aiops/deployment.yaml`
* **Sévérité** : `MEDIUM`
* **Description** : Root filesystem is writable. Risk of persistence on compromise.

### [Runs as Root] - Deployment/openwebui/container/openwebui
* **Fichier** : `/root/MasterPFE/infra/k8s/aiops/deployment.yaml`
* **Sévérité** : `HIGH`
* **Description** : Container is allowed to run as root.

### [Writable Root Filesystem] - Deployment/openwebui/container/openwebui
* **Fichier** : `/root/MasterPFE/infra/k8s/aiops/deployment.yaml`
* **Sévérité** : `MEDIUM`
* **Description** : Root filesystem is writable. Risk of persistence on compromise.

### [Runs as Root] - Deployment/dependency-graph-engine/container/engine
* **Fichier** : `/root/MasterPFE/infra/k8s/dependency-graph-engine/deployment.yaml`
* **Sévérité** : `HIGH`
* **Description** : Container is allowed to run as root.

### [Writable Root Filesystem] - Deployment/dependency-graph-engine/container/engine
* **Fichier** : `/root/MasterPFE/infra/k8s/dependency-graph-engine/deployment.yaml`
* **Sévérité** : `MEDIUM`
* **Description** : Root filesystem is writable. Risk of persistence on compromise.

### [hostPath Volume Mounted] - DaemonSet/wazuh-agent
* **Fichier** : `/root/MasterPFE/infra/k8s/wazuh/wazuh-agent-daemonset.yaml`
* **Sévérité** : `CRITICAL`
* **Description** : Volume 'var-log' mounts a host path. Risk of node compromise.

### [hostPath Volume Mounted] - DaemonSet/wazuh-agent
* **Fichier** : `/root/MasterPFE/infra/k8s/wazuh/wazuh-agent-daemonset.yaml`
* **Sévérité** : `CRITICAL`
* **Description** : Volume 'var-lib-docker-containers' mounts a host path. Risk of node compromise.

### [Runs as Root] - DaemonSet/wazuh-agent/container/wazuh-agent
* **Fichier** : `/root/MasterPFE/infra/k8s/wazuh/wazuh-agent-daemonset.yaml`
* **Sévérité** : `HIGH`
* **Description** : Container is allowed to run as root.

### [Privileged Container] - DaemonSet/wazuh-agent/container/wazuh-agent
* **Fichier** : `/root/MasterPFE/infra/k8s/wazuh/wazuh-agent-daemonset.yaml`
* **Sévérité** : `CRITICAL`
* **Description** : Container runs in privileged mode. Total breakout risk.

### [Writable Root Filesystem] - DaemonSet/wazuh-agent/container/wazuh-agent
* **Fichier** : `/root/MasterPFE/infra/k8s/wazuh/wazuh-agent-daemonset.yaml`
* **Sévérité** : `MEDIUM`
* **Description** : Root filesystem is writable. Risk of persistence on compromise.

### [Runs as Root] - Deployment/security-forensics-engine/container/engine
* **Fichier** : `/root/MasterPFE/infra/k8s/security-forensics-engine/deployment.yaml`
* **Sévérité** : `HIGH`
* **Description** : Container is allowed to run as root.

### [Writable Root Filesystem] - Deployment/security-forensics-engine/container/engine
* **Fichier** : `/root/MasterPFE/infra/k8s/security-forensics-engine/deployment.yaml`
* **Sévérité** : `MEDIUM`
* **Description** : Root filesystem is writable. Risk of persistence on compromise.

### [Runs as Root] - Deployment/kong/container/kong
* **Fichier** : `/root/MasterPFE/infra/k8s/kong/deployment.yaml`
* **Sévérité** : `HIGH`
* **Description** : Container is allowed to run as root.

### [Writable Root Filesystem] - Deployment/kong/container/kong
* **Fichier** : `/root/MasterPFE/infra/k8s/kong/deployment.yaml`
* **Sévérité** : `MEDIUM`
* **Description** : Root filesystem is writable. Risk of persistence on compromise.

### [Runs as Root] - Deployment/crossplane/container/crossplane
* **Fichier** : `/root/MasterPFE/infra/k8s/crossplane/provisioning.yaml`
* **Sévérité** : `HIGH`
* **Description** : Container is allowed to run as root.

### [Writable Root Filesystem] - Deployment/crossplane/container/crossplane
* **Fichier** : `/root/MasterPFE/infra/k8s/crossplane/provisioning.yaml`
* **Sévérité** : `MEDIUM`
* **Description** : Root filesystem is writable. Risk of persistence on compromise.

### [Runs as Root] - Deployment/portal-web-green/container/portal-web
* **Fichier** : `/root/MasterPFE/infra/k8s/strategies/blue-green-canary.yaml`
* **Sévérité** : `HIGH`
* **Description** : Container is allowed to run as root.

### [hostPath Volume Mounted] - DaemonSet/cilium
* **Fichier** : `/root/MasterPFE/infra/k8s/cilium/daemonset.yaml`
* **Sévérité** : `CRITICAL`
* **Description** : Volume 'cilium-run' mounts a host path. Risk of node compromise.

### [hostPath Volume Mounted] - DaemonSet/cilium
* **Fichier** : `/root/MasterPFE/infra/k8s/cilium/daemonset.yaml`
* **Sévérité** : `CRITICAL`
* **Description** : Volume 'bpf' mounts a host path. Risk of node compromise.

### [Runs as Root] - DaemonSet/cilium/container/cilium-agent
* **Fichier** : `/root/MasterPFE/infra/k8s/cilium/daemonset.yaml`
* **Sévérité** : `HIGH`
* **Description** : Container is allowed to run as root.

### [Privileged Container] - DaemonSet/cilium/container/cilium-agent
* **Fichier** : `/root/MasterPFE/infra/k8s/cilium/daemonset.yaml`
* **Sévérité** : `CRITICAL`
* **Description** : Container runs in privileged mode. Total breakout risk.

### [Writable Root Filesystem] - DaemonSet/cilium/container/cilium-agent
* **Fichier** : `/root/MasterPFE/infra/k8s/cilium/daemonset.yaml`
* **Sévérité** : `MEDIUM`
* **Description** : Root filesystem is writable. Risk of persistence on compromise.

### [Runs as Root] - Deployment/hubble-relay/container/hubble-relay
* **Fichier** : `/root/MasterPFE/infra/k8s/cilium/daemonset.yaml`
* **Sévérité** : `HIGH`
* **Description** : Container is allowed to run as root.

### [Writable Root Filesystem] - Deployment/hubble-relay/container/hubble-relay
* **Fichier** : `/root/MasterPFE/infra/k8s/cilium/daemonset.yaml`
* **Sévérité** : `MEDIUM`
* **Description** : Root filesystem is writable. Risk of persistence on compromise.

### [Runs as Root] - Deployment/hubble-ui/container/hubble-ui
* **Fichier** : `/root/MasterPFE/infra/k8s/cilium/daemonset.yaml`
* **Sévérité** : `HIGH`
* **Description** : Container is allowed to run as root.

### [Writable Root Filesystem] - Deployment/hubble-ui/container/hubble-ui
* **Fichier** : `/root/MasterPFE/infra/k8s/cilium/daemonset.yaml`
* **Sévérité** : `MEDIUM`
* **Description** : Root filesystem is writable. Risk of persistence on compromise.

### [hostPath Volume Mounted] - DaemonSet/promtail
* **Fichier** : `/root/MasterPFE/infra/k8s/observability/promtail.yaml`
* **Sévérité** : `CRITICAL`
* **Description** : Volume 'run' mounts a host path. Risk of node compromise.

### [hostPath Volume Mounted] - DaemonSet/promtail
* **Fichier** : `/root/MasterPFE/infra/k8s/observability/promtail.yaml`
* **Sévérité** : `CRITICAL`
* **Description** : Volume 'varlog' mounts a host path. Risk of node compromise.

### [hostPath Volume Mounted] - DaemonSet/promtail
* **Fichier** : `/root/MasterPFE/infra/k8s/observability/promtail.yaml`
* **Sévérité** : `CRITICAL`
* **Description** : Volume 'varlibdockercontainers' mounts a host path. Risk of node compromise.

### [Runs as Root] - DaemonSet/promtail/container/promtail
* **Fichier** : `/root/MasterPFE/infra/k8s/observability/promtail.yaml`
* **Sévérité** : `HIGH`
* **Description** : Container is allowed to run as root.

### [Runs as Root] - Deployment/loki/container/loki
* **Fichier** : `/root/MasterPFE/infra/k8s/observability/loki-deployment.yaml`
* **Sévérité** : `HIGH`
* **Description** : Container is allowed to run as root.

### [Runs as Root] - Deployment/grafana/container/grafana
* **Fichier** : `/root/MasterPFE/infra/k8s/observability/grafana-deployment.yaml`
* **Sévérité** : `HIGH`
* **Description** : Container is allowed to run as root.

### [Writable Root Filesystem] - Deployment/grafana/container/grafana
* **Fichier** : `/root/MasterPFE/infra/k8s/observability/grafana-deployment.yaml`
* **Sévérité** : `MEDIUM`
* **Description** : Root filesystem is writable. Risk of persistence on compromise.

### [Runs as Root] - Deployment/alertmanager/container/alertmanager
* **Fichier** : `/root/MasterPFE/infra/k8s/observability/alertmanager.yaml`
* **Sévérité** : `HIGH`
* **Description** : Container is allowed to run as root.

### [Runs as Root] - Deployment/tempo/container/tempo
* **Fichier** : `/root/MasterPFE/infra/k8s/observability/tempo/tempo-deployment.yaml`
* **Sévérité** : `HIGH`
* **Description** : Container is allowed to run as root.

### [Runs as Root] - Deployment/dora-exporter/container/exporter
* **Fichier** : `/root/MasterPFE/infra/k8s/observability/dora-exporter/deployment.yaml`
* **Sévérité** : `HIGH`
* **Description** : Container is allowed to run as root.

### [Writable Root Filesystem] - Deployment/dora-exporter/container/exporter
* **Fichier** : `/root/MasterPFE/infra/k8s/observability/dora-exporter/deployment.yaml`
* **Sévérité** : `MEDIUM`
* **Description** : Root filesystem is writable. Risk of persistence on compromise.

### [Runs as Root] - Deployment/falcosidekick/container/falcosidekick
* **Fichier** : `/root/MasterPFE/infra/k8s/runtime-detection/falcosidekick.yaml`
* **Sévérité** : `HIGH`
* **Description** : Container is allowed to run as root.

### [hostPath Volume Mounted] - DaemonSet/falco
* **Fichier** : `/root/MasterPFE/infra/k8s/runtime-detection/daemonset.yaml`
* **Sévérité** : `CRITICAL`
* **Description** : Volume 'dev-fs' mounts a host path. Risk of node compromise.

### [hostPath Volume Mounted] - DaemonSet/falco
* **Fichier** : `/root/MasterPFE/infra/k8s/runtime-detection/daemonset.yaml`
* **Sévérité** : `CRITICAL`
* **Description** : Volume 'proc-fs' mounts a host path. Risk of node compromise.

### [hostPath Volume Mounted] - DaemonSet/falco
* **Fichier** : `/root/MasterPFE/infra/k8s/runtime-detection/daemonset.yaml`
* **Sévérité** : `CRITICAL`
* **Description** : Volume 'boot-fs' mounts a host path. Risk of node compromise.

### [hostPath Volume Mounted] - DaemonSet/falco
* **Fichier** : `/root/MasterPFE/infra/k8s/runtime-detection/daemonset.yaml`
* **Sévérité** : `CRITICAL`
* **Description** : Volume 'lib-modules' mounts a host path. Risk of node compromise.

### [hostPath Volume Mounted] - DaemonSet/falco
* **Fichier** : `/root/MasterPFE/infra/k8s/runtime-detection/daemonset.yaml`
* **Sévérité** : `CRITICAL`
* **Description** : Volume 'usr-fs' mounts a host path. Risk of node compromise.

### [hostPath Volume Mounted] - DaemonSet/falco
* **Fichier** : `/root/MasterPFE/infra/k8s/runtime-detection/daemonset.yaml`
* **Sévérité** : `CRITICAL`
* **Description** : Volume 'etc-fs' mounts a host path. Risk of node compromise.

### [hostPath Volume Mounted] - DaemonSet/falco
* **Fichier** : `/root/MasterPFE/infra/k8s/runtime-detection/daemonset.yaml`
* **Sévérité** : `CRITICAL`
* **Description** : Volume 'sys-fs' mounts a host path. Risk of node compromise.

### [hostPath Volume Mounted] - DaemonSet/falco
* **Fichier** : `/root/MasterPFE/infra/k8s/runtime-detection/daemonset.yaml`
* **Sévérité** : `CRITICAL`
* **Description** : Volume 'tracing-fs' mounts a host path. Risk of node compromise.

### [hostPath Volume Mounted] - DaemonSet/falco
* **Fichier** : `/root/MasterPFE/infra/k8s/runtime-detection/daemonset.yaml`
* **Sévérité** : `CRITICAL`
* **Description** : Volume 'containerd-socket' mounts a host path. Risk of node compromise.

### [Runs as Root] - DaemonSet/falco/container/falco
* **Fichier** : `/root/MasterPFE/infra/k8s/runtime-detection/daemonset.yaml`
* **Sévérité** : `HIGH`
* **Description** : Container is allowed to run as root.

### [Privileged Container] - DaemonSet/falco/container/falco
* **Fichier** : `/root/MasterPFE/infra/k8s/runtime-detection/daemonset.yaml`
* **Sévérité** : `CRITICAL`
* **Description** : Container runs in privileged mode. Total breakout risk.

### [Writable Root Filesystem] - DaemonSet/falco/container/falco
* **Fichier** : `/root/MasterPFE/infra/k8s/runtime-detection/daemonset.yaml`
* **Sévérité** : `MEDIUM`
* **Description** : Root filesystem is writable. Risk of persistence on compromise.

### [hostPath Volume Mounted] - DaemonSet/tetragon
* **Fichier** : `/root/MasterPFE/infra/k8s/tetragon/daemonset.yaml`
* **Sévérité** : `CRITICAL`
* **Description** : Volume 'bpf' mounts a host path. Risk of node compromise.

### [hostPath Volume Mounted] - DaemonSet/tetragon
* **Fichier** : `/root/MasterPFE/infra/k8s/tetragon/daemonset.yaml`
* **Sévérité** : `CRITICAL`
* **Description** : Volume 'cgroup' mounts a host path. Risk of node compromise.

### [hostPath Volume Mounted] - DaemonSet/tetragon
* **Fichier** : `/root/MasterPFE/infra/k8s/tetragon/daemonset.yaml`
* **Sévérité** : `CRITICAL`
* **Description** : Volume 'proc' mounts a host path. Risk of node compromise.

### [Runs as Root] - DaemonSet/tetragon/container/tetragon
* **Fichier** : `/root/MasterPFE/infra/k8s/tetragon/daemonset.yaml`
* **Sévérité** : `HIGH`
* **Description** : Container is allowed to run as root.

### [Privileged Container] - DaemonSet/tetragon/container/tetragon
* **Fichier** : `/root/MasterPFE/infra/k8s/tetragon/daemonset.yaml`
* **Sévérité** : `CRITICAL`
* **Description** : Container runs in privileged mode. Total breakout risk.

### [Writable Root Filesystem] - DaemonSet/tetragon/container/tetragon
* **Fichier** : `/root/MasterPFE/infra/k8s/tetragon/daemonset.yaml`
* **Sévérité** : `MEDIUM`
* **Description** : Root filesystem is writable. Risk of persistence on compromise.

### [Runs as Root] - Deployment/opencost/container/opencost
* **Fichier** : `/root/MasterPFE/infra/k8s/finops/opencost.yaml`
* **Sévérité** : `HIGH`
* **Description** : Container is allowed to run as root.

### [Writable Root Filesystem] - Deployment/opencost/container/opencost
* **Fichier** : `/root/MasterPFE/infra/k8s/finops/opencost.yaml`
* **Sévérité** : `MEDIUM`
* **Description** : Root filesystem is writable. Risk of persistence on compromise.

### [Runs as Root] - StatefulSet/clickhouse/container/clickhouse
* **Fichier** : `/root/MasterPFE/infra/k8s/data-platform/deployment.yaml`
* **Sévérité** : `HIGH`
* **Description** : Container is allowed to run as root.

### [Writable Root Filesystem] - StatefulSet/clickhouse/container/clickhouse
* **Fichier** : `/root/MasterPFE/infra/k8s/data-platform/deployment.yaml`
* **Sévérité** : `MEDIUM`
* **Description** : Root filesystem is writable. Risk of persistence on compromise.

### [Runs as Root] - Deployment/minio/container/minio
* **Fichier** : `/root/MasterPFE/infra/k8s/data-platform/deployment.yaml`
* **Sévérité** : `HIGH`
* **Description** : Container is allowed to run as root.

### [Writable Root Filesystem] - Deployment/minio/container/minio
* **Fichier** : `/root/MasterPFE/infra/k8s/data-platform/deployment.yaml`
* **Sévérité** : `MEDIUM`
* **Description** : Root filesystem is writable. Risk of persistence on compromise.

### [Runs as Root] - Deployment/falco-talon/container/falco-talon
* **Fichier** : `/root/MasterPFE/infra/k8s/falco-talon/deployment.yaml`
* **Sévérité** : `HIGH`
* **Description** : Container is allowed to run as root.

### [Runs as Root] - Deployment/ollama/container/ollama
* **Fichier** : `/root/MasterPFE/infra/k8s/overlays/demo/patches/ollama-mock.yaml`
* **Sévérité** : `HIGH`
* **Description** : Container is allowed to run as root.

### [Writable Root Filesystem] - Deployment/ollama/container/ollama
* **Fichier** : `/root/MasterPFE/infra/k8s/overlays/demo/patches/ollama-mock.yaml`
* **Sévérité** : `MEDIUM`
* **Description** : Root filesystem is writable. Risk of persistence on compromise.

### [Runs as Root] - Deployment/otel-collector/container/otel-collector
* **Fichier** : `/root/MasterPFE/infra/k8s/otel/deployment.yaml`
* **Sévérité** : `HIGH`
* **Description** : Container is allowed to run as root.

### [Writable Root Filesystem] - Deployment/otel-collector/container/otel-collector
* **Fichier** : `/root/MasterPFE/infra/k8s/otel/deployment.yaml`
* **Sévérité** : `MEDIUM`
* **Description** : Root filesystem is writable. Risk of persistence on compromise.

### [Runs as Root] - Deployment/tempo/container/tempo
* **Fichier** : `/root/MasterPFE/infra/k8s/otel/deployment.yaml`
* **Sévérité** : `HIGH`
* **Description** : Container is allowed to run as root.

### [Writable Root Filesystem] - Deployment/tempo/container/tempo
* **Fichier** : `/root/MasterPFE/infra/k8s/otel/deployment.yaml`
* **Sévérité** : `MEDIUM`
* **Description** : Root filesystem is writable. Risk of persistence on compromise.

### [Runs as Root] - Deployment/coraza-waf/container/coraza-waf
* **Fichier** : `/root/MasterPFE/infra/k8s/coraza/deployment.yaml`
* **Sévérité** : `HIGH`
* **Description** : Container is allowed to run as root.

### [Writable Root Filesystem] - Deployment/coraza-waf/container/coraza-waf
* **Fichier** : `/root/MasterPFE/infra/k8s/coraza/deployment.yaml`
* **Sévérité** : `MEDIUM`
* **Description** : Root filesystem is writable. Risk of persistence on compromise.

### [Runs as Root] - Deployment/mlflow/container/mlflow
* **Fichier** : `/root/MasterPFE/infra/k8s/ml-platform/deployment.yaml`
* **Sévérité** : `HIGH`
* **Description** : Container is allowed to run as root.

### [Writable Root Filesystem] - Deployment/mlflow/container/mlflow
* **Fichier** : `/root/MasterPFE/infra/k8s/ml-platform/deployment.yaml`
* **Sévérité** : `MEDIUM`
* **Description** : Root filesystem is writable. Risk of persistence on compromise.

### [Runs as Root] - Deployment/feast/container/feast
* **Fichier** : `/root/MasterPFE/infra/k8s/ml-platform/deployment.yaml`
* **Sévérité** : `HIGH`
* **Description** : Container is allowed to run as root.

### [Writable Root Filesystem] - Deployment/feast/container/feast
* **Fichier** : `/root/MasterPFE/infra/k8s/ml-platform/deployment.yaml`
* **Sévérité** : `MEDIUM`
* **Description** : Root filesystem is writable. Risk of persistence on compromise.

### [Runs as Root] - Deployment/auth-users/container/auth-users
* **Fichier** : `/root/MasterPFE/infra/k8s/base/otel-patch.yaml`
* **Sévérité** : `HIGH`
* **Description** : Container is allowed to run as root.

### [Writable Root Filesystem] - Deployment/auth-users/container/auth-users
* **Fichier** : `/root/MasterPFE/infra/k8s/base/otel-patch.yaml`
* **Sévérité** : `MEDIUM`
* **Description** : Root filesystem is writable. Risk of persistence on compromise.

### [Runs as Root] - Deployment/chatbot-manager/container/chatbot-manager
* **Fichier** : `/root/MasterPFE/infra/k8s/base/otel-patch.yaml`
* **Sévérité** : `HIGH`
* **Description** : Container is allowed to run as root.

### [Writable Root Filesystem] - Deployment/chatbot-manager/container/chatbot-manager
* **Fichier** : `/root/MasterPFE/infra/k8s/base/otel-patch.yaml`
* **Sévérité** : `MEDIUM`
* **Description** : Root filesystem is writable. Risk of persistence on compromise.

### [Runs as Root] - Deployment/conversation-service/container/conversation-service
* **Fichier** : `/root/MasterPFE/infra/k8s/base/otel-patch.yaml`
* **Sévérité** : `HIGH`
* **Description** : Container is allowed to run as root.

### [Writable Root Filesystem] - Deployment/conversation-service/container/conversation-service
* **Fichier** : `/root/MasterPFE/infra/k8s/base/otel-patch.yaml`
* **Sévérité** : `MEDIUM`
* **Description** : Root filesystem is writable. Risk of persistence on compromise.

### [Runs as Root] - Deployment/audit-security-service/container/audit-security-service
* **Fichier** : `/root/MasterPFE/infra/k8s/base/otel-patch.yaml`
* **Sévérité** : `HIGH`
* **Description** : Container is allowed to run as root.

### [Writable Root Filesystem] - Deployment/audit-security-service/container/audit-security-service
* **Fichier** : `/root/MasterPFE/infra/k8s/base/otel-patch.yaml`
* **Sévérité** : `MEDIUM`
* **Description** : Root filesystem is writable. Risk of persistence on compromise.

### [Runs as Root] - Deployment/llm-orchestrator/container/llm-orchestrator
* **Fichier** : `/root/MasterPFE/infra/k8s/base/llm-orchestrator/deployment.yaml`
* **Sévérité** : `HIGH`
* **Description** : Container is allowed to run as root.

### [Runs as Root] - Deployment/portal-web/container/portal-web
* **Fichier** : `/root/MasterPFE/infra/k8s/base/portal-web/deployment.yaml`
* **Sévérité** : `HIGH`
* **Description** : Container is allowed to run as root.

### [Runs as Root] - StatefulSet/qdrant/container/qdrant
* **Fichier** : `/root/MasterPFE/infra/k8s/base/qdrant/deployment.yaml`
* **Sévérité** : `HIGH`
* **Description** : Container is allowed to run as root.

### [Writable Root Filesystem] - StatefulSet/qdrant/container/qdrant
* **Fichier** : `/root/MasterPFE/infra/k8s/base/qdrant/deployment.yaml`
* **Sévérité** : `MEDIUM`
* **Description** : Root filesystem is writable. Risk of persistence on compromise.

### [Runs as Root] - Deployment/knowledge-hub/container/knowledge-hub
* **Fichier** : `/root/MasterPFE/infra/k8s/base/knowledge-hub/deployment.yaml`
* **Sévérité** : `HIGH`
* **Description** : Container is allowed to run as root.

### [Runs as Root] - Deployment/ai-knowledge-graph/container/knowledge-graph
* **Fichier** : `/root/MasterPFE/infra/k8s/base/ai-knowledge-graph/deployment.yaml`
* **Sévérité** : `HIGH`
* **Description** : Container is allowed to run as root.

### [Runs as Root] - Deployment/audit-security-service/container/audit-security-service
* **Fichier** : `/root/MasterPFE/infra/k8s/base/audit-security-service/deployment.yaml`
* **Sévérité** : `HIGH`
* **Description** : Container is allowed to run as root.

### [Runs as Root] - Deployment/ai-security-orchestrator/container/orchestrator
* **Fichier** : `/root/MasterPFE/infra/k8s/base/ai-security-orchestrator/deployment.yaml`
* **Sévérité** : `HIGH`
* **Description** : Container is allowed to run as root.

### [Runs as Root] - Deployment/conversation-service/container/conversation-service
* **Fichier** : `/root/MasterPFE/infra/k8s/base/conversation-service/deployment.yaml`
* **Sévérité** : `HIGH`
* **Description** : Container is allowed to run as root.

### [Runs as Root] - Deployment/ollama/container/ollama
* **Fichier** : `/root/MasterPFE/infra/k8s/base/ollama/deployment.yaml`
* **Sévérité** : `HIGH`
* **Description** : Container is allowed to run as root.

### [Writable Root Filesystem] - Deployment/ollama/container/ollama
* **Fichier** : `/root/MasterPFE/infra/k8s/base/ollama/deployment.yaml`
* **Sévérité** : `MEDIUM`
* **Description** : Root filesystem is writable. Risk of persistence on compromise.

### [Runs as Root] - Deployment/security-auditor/container/security-auditor
* **Fichier** : `/root/MasterPFE/infra/k8s/base/security-auditor/deployment.yaml`
* **Sévérité** : `HIGH`
* **Description** : Container is allowed to run as root.

### [Runs as Root] - Deployment/chatbot-manager/container/chatbot-manager
* **Fichier** : `/root/MasterPFE/infra/k8s/base/chatbot-manager/deployment.yaml`
* **Sévérité** : `HIGH`
* **Description** : Container is allowed to run as root.

### [Runs as Root] - Deployment/auth-users/container/auth-users
* **Fichier** : `/root/MasterPFE/infra/k8s/base/auth-users/deployment.yaml`
* **Sévérité** : `HIGH`
* **Description** : Container is allowed to run as root.

### [Runs as Root] - Deployment/api-gateway/container/api-gateway
* **Fichier** : `/root/MasterPFE/infra/k8s/base/api-gateway/deployment.yaml`
* **Sévérité** : `HIGH`
* **Description** : Container is allowed to run as root.

### [Runs as Root] - Deployment/gatekeeper-controller-manager/container/manager
* **Fichier** : `/root/MasterPFE/infra/k8s/opa-gatekeeper/deployment.yaml`
* **Sévérité** : `HIGH`
* **Description** : Container is allowed to run as root.

### [Writable Root Filesystem] - Deployment/gatekeeper-controller-manager/container/manager
* **Fichier** : `/root/MasterPFE/infra/k8s/opa-gatekeeper/deployment.yaml`
* **Sévérité** : `MEDIUM`
* **Description** : Root filesystem is writable. Risk of persistence on compromise.

