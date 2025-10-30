output "namespace" {
  description = "Namespace where ArgoCD is installed"
  value       = var.namespace
}

output "argocd_server_url" {
  description = "ArgoCD server URL for NodePort access"
  value       = "http://localhost:${var.server_nodeport}"
}

output "argocd_admin_password_command" {
  description = "Command to retrieve ArgoCD admin password"
  value       = "kubectl -n ${var.namespace} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}

output "helm_release_name" {
  description = "Name of the Helm release"
  value       = helm_release.argocd.name
}

output "helm_release_version" {
  description = "Version of the deployed Helm release"
  value       = helm_release.argocd.version
}

output "helm_release_status" {
  description = "Status of the Helm release"
  value       = helm_release.argocd.status
}
