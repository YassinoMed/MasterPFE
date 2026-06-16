resource "helm_release" "argocd" {
  name             = var.release_name
  repository       = var.chart_repo
  chart            = var.chart_name
  namespace        = var.namespace
  create_namespace = true
  version          = var.chart_version
  wait             = true
  timeout          = var.timeout

  values = var.values

  depends_on = var.depends_on
}

variable "release_name" {
  type    = string
  default = "argocd"
}

variable "chart_repo" {
  type    = string
  default = "https://argoproj.github.io/argo-helm"
}

variable "chart_name" {
  type    = string
  default = "argo-cd"
}

variable "chart_version" {
  type    = string
  default = "7.3.0"
}

variable "namespace" {
  type    = string
  default = "argocd"
}

variable "timeout" {
  type    = number
  default = 600
}

variable "values" {
  type    = list(string)
  default = [<<-YAML
    global:
      domain: argocd.local
    configs:
      params:
        server.insecure: true
    server:
      extraArgs:
        - --insecure
    YAML
  ]
}

variable "depends_on" {
  type    = list(any)
  default = []
}

output "argocd_namespace" {
  value = var.namespace
}
