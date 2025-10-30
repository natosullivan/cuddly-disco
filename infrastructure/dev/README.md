# Development Kubernetes Cluster

This directory contains Terraform configuration for creating a local Kind cluster for development.

## Configuration

- **Cluster Name:** `kind-dev`
- **Kubernetes Version:** v1.27.0
- **Worker Nodes:** 0 (control-plane only)
- **Exposed Ports:** 3000 (frontend)

## Prerequisites

- Docker installed and running
- Terraform >= 1.0

## Usage

### Initialize Terraform

```bash
cd infrastructure/dev
terraform init
```

### Plan the deployment

```bash
terraform plan
```

### Create the cluster

```bash
terraform apply
```

### Access the cluster

After applying, the kubeconfig will be written to `~/.kube/kind-kind-dev`:

```bash
export KUBECONFIG=~/.kube/kind-kind-dev
kubectl get nodes
```

Or use the output:

```bash
export KUBECONFIG=$(terraform output -raw kubeconfig_path)
kubectl get nodes
```

### Destroy the cluster

```bash
terraform destroy
```

## Outputs

- `kubeconfig_path` - Path to the kubeconfig file
- `cluster_name` - Name of the cluster
- `cluster_endpoint` - API server endpoint
- `kubeconfig` - Raw kubeconfig content (sensitive)

## Port Mappings

The frontend port (3000) is exposed to the host, allowing you to access services running in the cluster at `http://localhost:3000`.

The backend port (5000) is NOT exposed to the host as services should communicate within the cluster.
