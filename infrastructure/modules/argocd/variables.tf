variable "namespace" {
  description = "Namespace to install ArgoCD"
  type        = string
  default     = "argocd"
}

variable "create_namespace" {
  description = "Create namespace if it doesn't exist"
  type        = bool
  default     = true
}

variable "chart_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "5.51.6"
}

variable "server_service_type" {
  description = "Service type for ArgoCD server (NodePort for Kind)"
  type        = string
  default     = "NodePort"
}

variable "server_nodeport" {
  description = "NodePort for ArgoCD UI access"
  type        = number
  default     = 30080
}

variable "enable_insecure" {
  description = "Run server without TLS (needed for local dev)"
  type        = bool
  default     = true
}

variable "values_override" {
  description = "Additional Helm values as YAML string"
  type        = string
  default     = ""
}
