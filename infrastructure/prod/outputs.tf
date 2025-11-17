output "kubeconfig_path" {
  description = "Path to the kubeconfig file for the prod cluster"
  value       = module.k8s.kubeconfig_path
}

output "cluster_name" {
  description = "Name of the created Kind cluster"
  value       = module.k8s.cluster_name
}

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint"
  value       = module.k8s.cluster_endpoint
}

output "kubeconfig" {
  description = "Raw kubeconfig file content (use with care)"
  value       = module.k8s.kubeconfig
  sensitive   = true
}

output "argocd_server_url" {
  description = "ArgoCD server URL"
  value       = module.argocd.argocd_server_url
}

output "argocd_admin_password_command" {
  description = "Command to retrieve ArgoCD admin password"
  value       = module.argocd.argocd_admin_password_command
}

output "argocd_namespace" {
  description = "Namespace where ArgoCD is installed"
  value       = module.argocd.namespace
}

output "client_certificate" {
  description = "Client certificate for cluster authentication"
  value       = module.k8s.client_certificate
  sensitive   = true
}

output "client_key" {
  description = "Client key for cluster authentication"
  value       = module.k8s.client_key
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Cluster CA certificate"
  value       = module.k8s.cluster_ca_certificate
  sensitive   = true
}
