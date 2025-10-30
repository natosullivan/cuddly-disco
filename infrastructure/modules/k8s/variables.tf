variable "cluster_name" {
  description = "Name of the Kind cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the cluster nodes (e.g., v1.27.0)"
  type        = string
  default     = "v1.27.0"
}

variable "num_worker_nodes" {
  description = "Number of worker nodes in the cluster (0 means control-plane only)"
  type        = number
  default     = 0

  validation {
    condition     = var.num_worker_nodes >= 0 && var.num_worker_nodes <= 10
    error_message = "Number of worker nodes must be between 0 and 10."
  }
}

variable "extra_port_mappings" {
  description = "Extra port mappings to expose services from the cluster to the host"
  type = list(object({
    container_port = number
    host_port      = number
    protocol       = optional(string, "TCP")
  }))
  default = [
    {
      container_port = 30080
      host_port      = 30080
      protocol       = "TCP"
    }
  ]
}

variable "wait_for_ready" {
  description = "Wait for the cluster to be ready before completing"
  type        = bool
  default     = true
}
