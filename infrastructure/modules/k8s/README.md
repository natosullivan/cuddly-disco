# Kubernetes (Kind) Cluster Module

This Terraform module creates a local Kubernetes cluster using [Kind (Kubernetes in Docker)](https://kind.sigs.k8s.io/).

## Features

- Creates a Kind cluster with configurable number of nodes
- Supports control-plane only or multi-node configurations
- Configurable port mappings for exposing services
- Automatic kubeconfig generation and file management
- Supports multiple Kubernetes versions

## Prerequisites

- Docker installed and running
- Terraform >= 1.0
- (Optional) Kind CLI for manual cluster management

## Usage

### Basic Example (Control-plane only)

```hcl
module "k8s" {
  source = "../modules/k8s"

  cluster_name = "my-dev-cluster"
}
```

### Example with Worker Nodes

```hcl
module "k8s" {
  source = "../modules/k8s"

  cluster_name       = "my-cluster"
  kubernetes_version = "v1.27.0"
  num_worker_nodes   = 2
}
```

### Example with Port Mappings

```hcl
module "k8s" {
  source = "../modules/k8s"

  cluster_name = "my-cluster"

  extra_port_mappings = [
    {
      container_port = 3000
      host_port      = 3000
      protocol       = "TCP"
    },
    {
      container_port = 5000
      host_port      = 5000
      protocol       = "TCP"
    }
  ]
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| cluster_name | Name of the Kind cluster | `string` | n/a | yes |
| kubernetes_version | Kubernetes version for the cluster nodes | `string` | `"v1.27.0"` | no |
| num_worker_nodes | Number of worker nodes (0 = control-plane only) | `number` | `0` | no |
| extra_port_mappings | Port mappings to expose services to host | `list(object)` | `[]` | no |
| wait_for_ready | Wait for cluster to be ready before completing | `bool` | `true` | no |

### extra_port_mappings Object Structure

```hcl
{
  container_port = number  # Port inside the container
  host_port      = number  # Port on the host machine
  protocol       = string  # "TCP" or "UDP" (optional, defaults to "TCP")
}
```

## Outputs

| Name | Description | Sensitive |
|------|-------------|-----------|
| kubeconfig | Raw kubeconfig file content | yes |
| kubeconfig_path | Path to the kubeconfig file | no |
| cluster_name | Name of the created cluster | no |
| cluster_endpoint | Kubernetes API server endpoint | no |
| client_certificate | Client certificate for authentication | yes |
| client_key | Client key for authentication | yes |
| cluster_ca_certificate | Cluster CA certificate | yes |

## Using the Cluster

After applying the Terraform configuration, the kubeconfig file will be automatically written to `~/.kube/kind-{cluster-name}`.

To use kubectl with the cluster:

```bash
export KUBECONFIG=~/.kube/kind-{cluster-name}
kubectl get nodes
```

Or use the kubeconfig path output:

```bash
export KUBECONFIG=$(terraform output -raw kubeconfig_path)
kubectl get nodes
```

## Notes

- The kubeconfig file is automatically managed by Terraform
- Port mappings are applied to the control-plane node
- Worker nodes do not have port mappings (services should use NodePort or LoadBalancer)
- The cluster runs entirely in Docker containers

## Cleaning Up

To destroy the cluster:

```bash
terraform destroy
```

This will remove the Kind cluster and the associated kubeconfig file.
