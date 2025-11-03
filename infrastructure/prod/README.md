# Production Kubernetes Environment

This directory contains Terraform configuration for deploying a production Kubernetes cluster using Kind (Kubernetes in Docker).

## Overview

The production environment creates:
- **Kubernetes Cluster**: Kind cluster named `kind-prod` with 1 control-plane + 2 worker nodes
- **ArgoCD**: GitOps continuous delivery tool with TLS enabled
- **Port Mappings**:
  - Port 30080 (ArgoCD UI)
  - Port 3000 (Frontend application via NodePort 30001)

## Production vs Development

| Feature | Development | Production |
|---------|-------------|------------|
| Cluster Name | `kind-dev` | `kind-prod` |
| Worker Nodes | 0 (control-plane only) | 2 workers |
| ArgoCD TLS | Disabled (insecure) | Enabled |
| Kubernetes Version | v1.27.0 | v1.27.0 |

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop) running
- [Terraform](https://www.terraform.io/downloads) >= 1.0
- [kubectl](https://kubernetes.io/docs/tasks/tools/) for cluster access

## Deployment

### 1. Initialize Terraform

```bash
cd infrastructure/prod
terraform init
```

### 2. Review the Plan

```bash
terraform plan
```

### 3. Deploy the Cluster

```bash
terraform apply
```

Type `yes` when prompted to confirm.

### 4. Configure kubectl

```bash
# Set kubeconfig environment variable
export KUBECONFIG=~/.kube/kind-kind-prod

# Verify cluster access
kubectl get nodes
```

Expected output:
```
NAME                      STATUS   ROLES           AGE   VERSION
kind-prod-control-plane   Ready    control-plane   1m    v1.27.0
kind-prod-worker          Ready    <none>          1m    v1.27.0
kind-prod-worker2         Ready    <none>          1m    v1.27.0
```

### 5. Access ArgoCD

Get the admin password:

```bash
eval $(terraform output -raw argocd_admin_password_command)
echo $ARGOCD_ADMIN_PASSWORD
```

Open ArgoCD UI:
```bash
# With HTTPS (production has TLS enabled)
open https://localhost:30080

# Login credentials:
# Username: admin
# Password: (from command above)
```

**Note**: You may see a certificate warning because Kind uses a self-signed certificate. This is expected for local development.

## Deploy Applications

### Deploy Frontend Application

```bash
# From repository root
kubectl apply -f k8s/argocd-apps/frontend-app.yaml
```

### Deploy Backend Application

```bash
kubectl apply -f k8s/argocd-apps/backend-app.yaml
```

### Verify Deployments

```bash
# Check ArgoCD applications
kubectl get applications -n argocd

# Check frontend pods
kubectl get pods -n cuddly-disco-frontend

# Check backend pods
kubectl get pods -n cuddly-disco-backend
```

## Access Applications

### Frontend
- **URL**: http://localhost:3000
- **Type**: NodePort (30001 → host 3000)
- **Description**: React frontend with Next.js SSR

### Backend
- **URL**: Internal only (ClusterIP)
- **Type**: Not exposed externally
- **Access**: Via frontend nginx proxy or kubectl port-forward

To test backend directly:
```bash
kubectl port-forward -n cuddly-disco-backend svc/backend-service 5000:5000
curl http://localhost:5000/health
```

## Terraform Outputs

After deployment, useful outputs are available:

```bash
# Get kubeconfig path
terraform output kubeconfig_path

# Get cluster endpoint
terraform output cluster_endpoint

# Get ArgoCD password command
terraform output argocd_admin_password_command
```

## Customization

### Override Variables

Create a `terraform.tfvars` file:

```hcl
cluster_name       = "my-prod-cluster"
num_worker_nodes   = 3
kubernetes_version = "v1.28.0"
```

Then apply:
```bash
terraform apply
```

### Add More Port Mappings

Edit `variables.tf`:

```hcl
variable "extra_port_mappings" {
  default = [
    {
      container_port = 30080
      host_port      = 30080
      protocol       = "TCP"
    },
    {
      container_port = 30001
      host_port      = 3000
      protocol       = "TCP"
    },
    {
      container_port = 30002
      host_port      = 8080
      protocol       = "TCP"
    }
  ]
}
```

## Troubleshooting

### Cluster Not Starting

```bash
# Check Docker is running
docker ps

# View Kind logs
kind get clusters
docker logs kind-prod-control-plane
```

### ArgoCD Not Accessible

```bash
# Check ArgoCD pods
kubectl get pods -n argocd

# Check ArgoCD service
kubectl get svc -n argocd argocd-server

# Port forward if NodePort not working
kubectl port-forward -n argocd svc/argocd-server 8080:443
open https://localhost:8080
```

### Application Not Deploying

```bash
# Check ArgoCD application status
kubectl describe application frontend -n argocd
kubectl describe application backend -n argocd

# Check ArgoCD logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server

# Force sync
kubectl patch application frontend -n argocd \
  --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

## Cleanup

To destroy the entire cluster:

```bash
terraform destroy
```

Type `yes` when prompted.

This will:
- Delete the Kind cluster
- Remove the kubeconfig file
- Clean up all resources

## Production Considerations

**Note**: This is a local Kind cluster, not suitable for actual production workloads. For real production deployments, consider:

- **Cloud Providers**: GKE, EKS, AKS for managed Kubernetes
- **High Availability**: Multiple control-plane nodes
- **Persistent Storage**: Proper storage classes and PVCs
- **Monitoring**: Prometheus, Grafana
- **Logging**: ELK stack or cloud logging
- **Security**: Network policies, RBAC, pod security policies
- **Backup**: Velero or similar backup solutions
- **Ingress**: Proper ingress controller (nginx, traefik)
- **TLS**: Cert-manager for automated certificate management

## Next Steps

1. **Configure Applications**: Update Helm values in `k8s/frontend/values.yaml` and `k8s/backend/values.yaml`
2. **Set Up CI/CD**: GitHub Actions will automatically deploy on commits to main
3. **Monitor Health**: Use ArgoCD UI to monitor application health
4. **Update Images**: Push new images to GHCR, update image tags in values.yaml

## Resources

- [Kind Documentation](https://kind.sigs.k8s.io/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Terraform Documentation](https://www.terraform.io/docs)
