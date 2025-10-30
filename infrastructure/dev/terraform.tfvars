# Development environment configuration for Kind cluster
cluster_name       = "kind-dev"
kubernetes_version = "v1.27.0"
num_worker_nodes   = 0

# Expose ArgoCD UI and frontend ports
extra_port_mappings = [
  {
    container_port = 30080 # ArgoCD UI NodePort
    host_port      = 30080
    protocol       = "TCP"
  },
  {
    container_port = 30001 # Frontend NodePort
    host_port      = 3000
    protocol       = "TCP"
  }
]
