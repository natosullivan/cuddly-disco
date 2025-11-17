terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

# Create ArgoCD cluster secret for remote cluster registration
resource "kubernetes_secret" "argocd_cluster" {
  metadata {
    name      = "cluster-${var.cluster_name}"
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "cluster"
    }
  }

  data = {
    name   = var.cluster_name
    server = var.cluster_endpoint
    config = jsonencode({
      tlsClientConfig = {
        insecure = false
        caData   = var.cluster_ca_certificate
        certData = var.client_certificate
        keyData  = var.client_key
      }
    })
  }

  type = "Opaque"
}
