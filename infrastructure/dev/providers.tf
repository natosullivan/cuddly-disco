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
