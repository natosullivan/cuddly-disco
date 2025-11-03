module "k8s" {
  source = "../modules/k8s"

  cluster_name       = var.cluster_name
  kubernetes_version = var.kubernetes_version
  num_worker_nodes   = var.num_worker_nodes

  # Expose ArgoCD UI (30080) and frontend NodePort (30001 → host 3000)
  extra_port_mappings = var.extra_port_mappings
}

module "argocd" {
  source = "../modules/argocd"

  # Depends on cluster being ready
  depends_on = [module.k8s]

  namespace           = "argocd"
  server_service_type = "NodePort"
  server_nodeport     = 30080
  enable_insecure     = false # TLS enabled for production
}
