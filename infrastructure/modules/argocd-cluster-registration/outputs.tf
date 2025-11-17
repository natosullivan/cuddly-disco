output "cluster_secret_name" {
  description = "Name of the ArgoCD cluster secret created"
  value       = kubernetes_secret.argocd_cluster.metadata[0].name
}

output "cluster_name" {
  description = "Name of the registered cluster"
  value       = var.cluster_name
}
