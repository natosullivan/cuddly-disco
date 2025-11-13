# Management Cluster Environment

This directory contains the Terraform configuration for the management Kind cluster with ArgoCD.

## Configuration

- **Cluster Name:** `kind-mgmt`
- **Kubernetes Version:** v1.27.0
- **Worker Nodes:** 0 (control-plane only)
- **ArgoCD UI Port:** 30082 (mapped from NodePort 30080)

## Port Mappings

- ArgoCD UI: NodePort 30080 → host 30082

Port mappings are configured to avoid conflicts with dev and prod environments:
- Dev: ArgoCD on 30080
- Prod: ArgoCD on 30081
- Mgmt: ArgoCD on 30082

## Quick Start

```bash
# Initialize and apply Terraform
terraform init
terraform apply

# Configure kubectl
export KUBECONFIG=~/.kube/kind-kind-mgmt

# Verify cluster
kubectl get nodes
kubectl get pods -n argocd

# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo

# Access ArgoCD UI
open http://localhost:30082
# Login: admin/<password from above>
```

## Destroy

```bash
terraform destroy
```
