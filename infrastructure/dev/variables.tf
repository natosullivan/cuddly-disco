variable "cluster_name" {
  description = "Name of the Kind cluster"
  type        = string
  default     = "kind-dev"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the cluster nodes"
  type        = string
  default     = "v1.27.0"
}

variable "num_worker_nodes" {
  description = "Number of worker nodes in the cluster"
  type        = number
  default     = 0
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
      container_port = 30001
      host_port      = 3000
      protocol       = "TCP"
    }
  ]
}
