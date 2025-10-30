# ArgoCD Terraform Module

This Terraform module installs ArgoCD on a Kubernetes cluster using the official Helm chart.

## Features

- Installs ArgoCD via Helm chart
- Configurable service type (NodePort for Kind, LoadBalancer for cloud)
- Optional namespace creation
- Supports insecure mode for local development
- Customizable via Helm values override

## Prerequisites

- Kubernetes cluster (Kind, EKS, GKE, etc.)
- Helm >= 3.0
- kubectl configured to access the cluster

## Usage

### Basic Example

```hcl
module "argocd" {
  source = "../modules/argocd"

  namespace = "argocd"
}
```

### Example with NodePort (Kind/Local)

```hcl
module "argocd" {
  source = "../modules/argocd"

  namespace           = "argocd"
  server_service_type = "NodePort"
  server_nodeport     = 30080
  enable_insecure     = true  # Disable TLS for local dev
}
```

### Example with LoadBalancer (Cloud)

```hcl
module "argocd" {
  source = "../modules/argocd"

  namespace           = "argocd"
  server_service_type = "LoadBalancer"
  enable_insecure     = false  # Enable TLS for production
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| namespace | Namespace to install ArgoCD | `string` | `"argocd"` | no |
| create_namespace | Create namespace if it doesn't exist | `bool` | `true` | no |
| chart_version | ArgoCD Helm chart version | `string` | `"5.51.6"` | no |
| server_service_type | Service type for ArgoCD server | `string` | `"NodePort"` | no |
| server_nodeport | NodePort for ArgoCD UI access | `number` | `30080` | no |
| enable_insecure | Run server without TLS | `bool` | `true` | no |
| values_override | Additional Helm values as YAML string | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| namespace | Namespace where ArgoCD is installed |
| argocd_server_url | ArgoCD server URL for access |
| argocd_admin_password_command | Command to retrieve admin password |
| helm_release_name | Name of the Helm release |
| helm_release_version | Version of the deployed Helm release |
| helm_release_status | Status of the Helm release |

## Accessing ArgoCD

### Get Admin Password

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

Or use the Terraform output:

```bash
eval $(terraform output -raw argocd_admin_password_command)
```

### Access the UI

**NodePort (Kind/Local):**
```bash
# Access at http://localhost:30080
# Login: admin / <password-from-above>
```

**Port-Forward (Alternative):**
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Access at https://localhost:8080
```

**LoadBalancer (Cloud):**
```bash
kubectl get svc argocd-server -n argocd
# Use EXTERNAL-IP
```

## Using ArgoCD CLI

Install ArgoCD CLI:

```bash
# macOS
brew install argocd

# Linux
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/
```

Login:

```bash
# Get password
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)

# Login
argocd login localhost:30080 --username admin --password $ARGOCD_PASSWORD --insecure
```

## Notes

- The `insecure` mode disables TLS - only use for local development
- Default admin password is auto-generated in `argocd-initial-admin-secret`
- Change the admin password after first login in production
- ApplicationSet controller is enabled by default

## Cleaning Up

To uninstall ArgoCD:

```bash
terraform destroy
```

This will remove the Helm release and optionally the namespace.
