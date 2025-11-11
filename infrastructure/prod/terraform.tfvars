# Development environment configuration for Kind cluster
cluster_name       = "kind-prod"
kubernetes_version = "v1.27.0"
num_worker_nodes   = 0

# Expose ArgoCD UI and frontend ports (different from dev to avoid conflicts)
extra_port_mappings = [
  {
    container_port = 30080 # ArgoCD UI NodePort
    host_port      = 30081 # Different from dev (30080)
    protocol       = "TCP"
  },
  {
    container_port = 30001 # Frontend NodePort
    host_port      = 3001  # Different from dev (3000)
    protocol       = "TCP"
  }
]
