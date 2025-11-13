# Management environment configuration for Kind cluster
cluster_name       = "kind-mgmt"
kubernetes_version = "v1.27.0"
num_worker_nodes   = 0

# Expose ArgoCD UI (different from dev and prod to avoid conflicts)
extra_port_mappings = [
  {
    container_port = 30080 # ArgoCD UI NodePort
    host_port      = 30082 # Different from dev (30080) and prod (30081)
    protocol       = "TCP"
  }
]
