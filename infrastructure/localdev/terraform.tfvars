# Local development environment configuration for Kind cluster
# This cluster is for direct deployment without ArgoCD
cluster_name       = "kind-localdev"
kubernetes_version = "v1.27.0"
num_worker_nodes   = 0

# Gateway hostname for Istio routing
gateway_hostname = "localdev.cuddly-disco.ai.localhost"

# Expose Gateway API on port 8080 (avoids conflicts with dev:3000, prod:3001)
extra_port_mappings = [
  {
    container_port = 30001 # Gateway API NodePort
    host_port      = 8080
    protocol       = "TCP"
  }
]
