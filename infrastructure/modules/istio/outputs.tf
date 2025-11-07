output "gateway_name" {
  description = "Name of the created Gateway resource"
  value       = var.gateway_name
}

output "gateway_namespace" {
  description = "Namespace where Gateway is deployed"
  value       = var.namespace
}

output "gateway_hostname" {
  description = "Configured hostname for the Gateway"
  value       = var.gateway_hostname
}

output "gateway_nodeport" {
  description = "NodePort used by Gateway API gateway service"
  value       = 30001
}
