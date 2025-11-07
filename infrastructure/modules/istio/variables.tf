variable "kubeconfig_path" {
  description = "Path to the kubeconfig file for the Kubernetes cluster"
  type        = string
}

variable "namespace" {
  description = "Namespace to install Istio"
  type        = string
  default     = "istio-system"
}

variable "create_namespace" {
  description = "Create namespace if it doesn't exist"
  type        = bool
  default     = true
}

variable "gateway_hostname" {
  description = "Hostname for the Gateway resource (e.g., dev.cuddly-disco.ai.localhost)"
  type        = string
}

variable "gateway_name" {
  description = "Name of the Gateway resource"
  type        = string
  default     = "cuddly-disco-gateway"
}

variable "istio_base_version" {
  description = "Istio base Helm chart version"
  type        = string
  default     = "1.24.2"
}

variable "istiod_version" {
  description = "Istio istiod Helm chart version"
  type        = string
  default     = "1.24.2"
}

variable "gateway_api_version" {
  description = "Gateway API CRD version"
  type        = string
  default     = "v1.2.1"
}
