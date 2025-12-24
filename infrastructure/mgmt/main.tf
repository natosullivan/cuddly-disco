module "k8s" {
  source = "../modules/k8s"

  cluster_name       = var.cluster_name
  kubernetes_version = var.kubernetes_version
  num_worker_nodes   = var.num_worker_nodes

  # Expose ArgoCD UI (30080 → host 30082)
  extra_port_mappings = var.extra_port_mappings
}

module "argocd" {
  source = "../modules/argocd"

  # Depends on cluster being ready
  depends_on = [module.k8s]

  namespace           = "argocd"
  server_service_type = "NodePort"
  server_nodeport     = 30080
  enable_insecure     = true # For local management without TLS
}

module "applicationsets" {
  source = "../modules/applicationsets"

  # Depends on ArgoCD being ready
  depends_on = [module.argocd]

  team_apps_file          = "${path.module}/../../k8s/argocd-appsets/team-apps.yaml"
  team_apps_branches_file = "${path.module}/../../k8s/argocd-appsets/team-apps-branches.yaml"
  argocd_ready            = module.argocd
}
