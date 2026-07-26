# Enterprise DNS Configuration Module

resource "null_resource" "dns_record_k8s_api" {
  triggers = {
    domain = var.domain_name
    ip     = var.api_lb_ip
  }

  provisioner "local-exec" {
    command = "echo 'DNS Record: k8s-api.${var.domain_name} -> ${var.api_lb_ip}'"
  }
}

resource "null_resource" "dns_record_ingress" {
  triggers = {
    domain = var.domain_name
    ip     = var.ingress_lb_ip
  }

  provisioner "local-exec" {
    command = "echo 'DNS Record: *.apps.${var.domain_name} -> ${var.ingress_lb_ip}'"
  }
}
