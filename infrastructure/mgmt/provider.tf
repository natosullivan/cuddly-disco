provider "kind" {}

provider "local" {}

provider "kubernetes" {
  host                   = module.k8s.cluster_endpoint
  client_certificate     = module.k8s.client_certificate
  client_key             = module.k8s.client_key
  cluster_ca_certificate = module.k8s.cluster_ca_certificate
}

provider "helm" {
  kubernetes {
    host                   = module.k8s.cluster_endpoint
    client_certificate     = module.k8s.client_certificate
    client_key             = module.k8s.client_key
    cluster_ca_certificate = module.k8s.cluster_ca_certificate
  }
}

provider "argocd" {
  username = "admin"
  password = data.kubernetes_secret.argocd_admin.data["password"]

  port_forward_with_namespace = "argocd"
  insecure                   = true
  plain_text                  = true
  grpc_web                    = true

  kubernetes {
    host                   = module.k8s.cluster_endpoint
    cluster_ca_certificate = module.k8s.cluster_ca_certificate
    client_certificate     = module.k8s.client_certificate
    client_key             = module.k8s.client_key
  }
}
