output "kubeconfig_path" {
  description = "Path to the kubeconfig file"
  value       = module.k8s.kubeconfig_path
}

output "cluster_name" {
  description = "Name of the Kind cluster"
  value       = module.k8s.cluster_name
}

output "argocd_admin_password_command" {
  description = "Command to retrieve ArgoCD admin password"
  value       = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo"
}

output "argocd_ui_url" {
  description = "URL to access ArgoCD UI"
  value       = "http://localhost:30082"
}

output "registered_clusters" {
  description = "List of clusters registered with ArgoCD"
  value = concat(
    argocd_cluster.dev[*].name,
    argocd_cluster.prod[*].name
  )
}
