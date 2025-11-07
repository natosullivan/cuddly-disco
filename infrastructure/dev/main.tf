module "k8s" {
  source = "../modules/k8s"

  cluster_name       = var.cluster_name
  kubernetes_version = var.kubernetes_version
  num_worker_nodes   = var.num_worker_nodes

  # Expose Gateway API (30001 → host 3000)
  extra_port_mappings = var.extra_port_mappings
}

module "argocd" {
  source = "../modules/argocd"

  # Depends on cluster being ready
  depends_on = [module.k8s]

  namespace           = "argocd"
  server_service_type = "NodePort"
  server_nodeport     = 30080
  enable_insecure     = true # For local dev without TLS
}

module "istio" {
  source = "../modules/istio"

  # Depends on cluster being ready
  depends_on = [module.k8s]

  kubeconfig_path  = module.k8s.kubeconfig_path
  namespace        = "istio-system"
  gateway_hostname = "dev.cuddly-disco.ai.localhost"
  gateway_name     = "cuddly-disco-gateway"
}
