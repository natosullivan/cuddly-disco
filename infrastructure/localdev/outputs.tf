output "kubeconfig_path" {
  description = "Path to the kubeconfig file for the localdev cluster"
  value       = module.k8s.kubeconfig_path
}

output "cluster_name" {
  description = "Name of the created Kind cluster"
  value       = module.k8s.cluster_name
}

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint (external/localhost)"
  value       = module.k8s.cluster_endpoint
}

output "cluster_endpoint_internal" {
  description = "Kubernetes API server endpoint (internal/Docker network)"
  value       = "https://${module.k8s.cluster_name}-control-plane:6443"
}

output "kubeconfig" {
  description = "Raw kubeconfig file content (use with care)"
  value       = module.k8s.kubeconfig
  sensitive   = true
}

output "gateway_hostname" {
  description = "Hostname for the Istio Gateway"
  value       = var.gateway_hostname
}

output "gateway_url" {
  description = "URL to access applications via Gateway"
  value       = "http://${var.gateway_hostname}:8080"
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
