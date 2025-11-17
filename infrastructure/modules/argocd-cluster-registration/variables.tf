variable "cluster_name" {
  description = "Name of the cluster to register with ArgoCD"
  type        = string
}

variable "cluster_endpoint" {
  description = "API server endpoint of the cluster"
  type        = string
}

variable "cluster_ca_certificate" {
  description = "Base64-encoded CA certificate of the cluster"
  type        = string
  sensitive   = true
}

variable "client_certificate" {
  description = "Base64-encoded client certificate for cluster authentication"
  type        = string
  sensitive   = true
}

variable "client_key" {
  description = "Base64-encoded client key for cluster authentication"
  type        = string
  sensitive   = true
}
