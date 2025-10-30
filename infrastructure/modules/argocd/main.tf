resource "kubernetes_namespace" "argocd" {
  count = var.create_namespace ? 1 : 0

  metadata {
    name = var.namespace
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.chart_version
  namespace  = var.namespace

  # Wait for namespace to be created
  depends_on = [kubernetes_namespace.argocd]

  # Core ArgoCD server configuration
  set {
    name  = "server.service.type"
    value = var.server_service_type
  }

  set {
    name  = "server.service.nodePortHttp"
    value = var.server_nodeport
  }

  # Disable TLS for local development
  dynamic "set" {
    for_each = var.enable_insecure ? [1] : []
    content {
      name  = "server.extraArgs[0]"
      value = "--insecure"
    }
  }

  # Disable Dex (SSO) for local dev
  set {
    name  = "dex.enabled"
    value = "false"
  }

  # Disable notifications for simplicity
  set {
    name  = "notifications.enabled"
    value = "false"
  }

  # Enable ApplicationSet controller
  set {
    name  = "applicationSet.enabled"
    value = "true"
  }

  # Additional values override
  values = var.values_override != "" ? [var.values_override] : []

  # Wait for resources to be ready
  wait          = true
  wait_for_jobs = true
  timeout       = 600
}
