resource "kind_cluster" "this" {
  name            = var.cluster_name
  wait_for_ready  = var.wait_for_ready
  node_image      = "kindest/node:${var.kubernetes_version}"
  kubeconfig_path = pathexpand("~/.kube/kind-${var.cluster_name}")

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    # Control plane node
    node {
      role = "control-plane"

      # Apply port mappings only to control plane node
      dynamic "extra_port_mappings" {
        for_each = var.extra_port_mappings
        content {
          container_port = extra_port_mappings.value.container_port
          host_port      = extra_port_mappings.value.host_port
          protocol       = extra_port_mappings.value.protocol
        }
      }
    }

    # Worker nodes (if any)
    dynamic "node" {
      for_each = range(var.num_worker_nodes)
      content {
        role = "worker"
      }
    }
  }
}

# Write kubeconfig to file for easy kubectl access
resource "local_file" "kubeconfig" {
  content         = kind_cluster.this.kubeconfig
  filename        = pathexpand("~/.kube/kind-${var.cluster_name}")
  file_permission = "0600"
}
