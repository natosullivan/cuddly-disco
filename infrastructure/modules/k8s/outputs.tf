output "kubeconfig" {
  description = "Raw kubeconfig file content for the Kind cluster"
  value       = kind_cluster.this.kubeconfig
  sensitive   = true
}

output "kubeconfig_path" {
  description = "Path to the kubeconfig file"
  value       = local_file.kubeconfig.filename
}

output "cluster_name" {
  description = "Name of the created Kind cluster"
  value       = kind_cluster.this.name
}

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint"
  value       = kind_cluster.this.endpoint
}

output "client_certificate" {
  description = "Client certificate for cluster authentication"
  value       = kind_cluster.this.client_certificate
  sensitive   = true
}

output "client_key" {
  description = "Client key for cluster authentication"
  value       = kind_cluster.this.client_key
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Cluster CA certificate"
  value       = kind_cluster.this.cluster_ca_certificate
  sensitive   = true
}
