# Audit logging du kube-apiserver (activé le 2026-09-26 sur kind-securerag-dev)

## État actuel
Le manifest statique du kube-apiserver (dans le conteneur control-plane) embarque :
`--audit-log-path=/var/log/kubernetes/audit.log --audit-log-maxage=30
--audit-log-maxbackup=10 --audit-log-maxsize=100
--audit-policy-file=/etc/kubernetes/audit-policy.yaml`

La policy `audit-policy.yaml` (niveau Metadata, omitManagedFields) est déployée
dans le nœud à `/etc/kubernetes/audit-policy.yaml`.

## Pour un recréation du cluster kind — patch kubeadm à ajouter
```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
kubeadmConfigPatches:
- |
  apiVersion: kubeadm.k8s.io/v1beta4
  kind: ClusterConfiguration
  apiServer:
    extraArgs:
      audit-log-path: /var/log/kubernetes/audit.log
      audit-log-maxage: "30"
      audit-log-maxbackup: "10"
      audit-log-maxsize: "100"
      audit-policy-file: /etc/kubernetes/audit-policy.yaml
    extraVolumes:
      - name: audit-log
        hostPath: /var/log/kubernetes
        mountPath: /var/log/kubernetes
        pathType: DirectoryOrCreate
# + pousser audit-policy.yaml dans le nœud avant le démarrage
# (docker cp <control-plane>:/etc/kubernetes/audit-policy.yaml)
```
