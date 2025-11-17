# Team Applications

This directory contains Helm charts for team applications deployed via ArgoCD ApplicationSets.

## How It Works

The `team-apps` ApplicationSet (defined in `k8s/argocd-appsets/team-apps.yaml`) automatically discovers team applications from this directory and deploys them to both dev and prod clusters.

### Architecture

```
Management Cluster (kind-mgmt)
├── ArgoCD ApplicationSet Controller
└── Team Apps ApplicationSet
    ├── Discovers: k8s/team-apps/* (app directories)
    ├── Environments: dev, prod
    └── Generates: Applications for each app × environment
        ├── frontend-dev → kind-dev cluster
        ├── frontend-prod → kind-prod cluster
        ├── backend-dev → kind-dev cluster
        └── backend-prod → kind-prod cluster
```

## Adding a New Team

To add a new team application:

### 1. Copy the Frontend Template

```bash
cp -r k8s/team-apps/frontend k8s/team-apps/team-analytics
```

### 2. Update Team Configuration

Edit `k8s/team-apps/team-analytics/config.yaml`:

```yaml
team:
  name: team-analytics
  namespace: team-analytics
  routePath: /analytics
  owner: "analytics-team@example.com"
  slackChannel: "#analytics-alerts"
  version:
    dev: main
    prod: v1.0.0
```

### 3. Update Helm Chart

Edit `k8s/team-apps/team-analytics/Chart.yaml`:

```yaml
name: team-analytics-app
description: Team Analytics application deployment
```

### 4. Update Values Files

Edit `k8s/team-apps/team-analytics/values.yaml`:

```yaml
teamName: team-analytics
routePath: /analytics
namespace:
  name: team-analytics
service:
  name: team-analytics-service
config:
  location: "Analytics Team"
  backendUrl: "http://backend-service.backend.svc.cluster.local:5000"
```

Update `values-dev.yaml` and `values-prod.yaml` similarly.

### 5. Commit and Push

```bash
git add k8s/team-apps/team-analytics
git commit -m "feat: Add team-analytics application"
git push
```

The ApplicationSet will automatically detect the new directory and create:
- `team-analytics-dev` Application → deploys to kind-dev cluster
- `team-analytics-prod` Application → deploys to kind-prod cluster

## Directory Structure

Each team directory must contain:

```
team-name/
├── config.yaml          # Team metadata (optional, for future use)
├── Chart.yaml           # Helm chart definition
├── values.yaml          # Base Helm values
├── values-dev.yaml      # Dev environment overrides
├── values-prod.yaml     # Prod environment overrides
└── templates/           # Helm templates
    ├── _helpers.tpl     # Template helpers
    ├── namespace.yaml   # Namespace creation
    ├── configmap.yaml   # Environment variables
    ├── deployment.yaml  # Pod deployment
    ├── service.yaml     # ClusterIP service
    └── httproute.yaml   # Gateway API routing
```

## Environment Configuration

### Dev Environment
- Cluster: `kind-dev`
- Gateway: `dev.cuddly-disco.ai.localhost`
- Replicas: 1 (lower for cost)
- Resources: Reduced limits

### Prod Environment
- Cluster: `kind-prod`
- Gateway: `cuddly-disco.ai.localhost`
- Replicas: 2-3 (HA configuration)
- Resources: Production limits

## Routing

Each app gets path-based routing:

- **Frontend Dev**: `http://dev.cuddly-disco.ai.localhost:3000/`
- **Frontend Prod**: `http://cuddly-disco.ai.localhost:3001/`
- **Backend**: Internal only - `http://backend-service.backend.svc.cluster.local:5000`
- **Team Apps**: Custom paths like `/analytics`, `/reports`, etc.

## Version Control

Teams can specify different versions per environment in `config.yaml`:

```yaml
version:
  dev: main       # Latest code from main branch
  prod: v1.2.3    # Specific Git tag for stability
```

*Note: Version pinning via `config.yaml` is planned for future implementation. Currently, all environments deploy from `HEAD`.*

## Monitoring Applications

View all applications in ArgoCD:

```bash
# Set management cluster context
export KUBECONFIG=~/.kube/kind-kind-mgmt

# List all applications
kubectl get applications -n argocd

# View specific application
kubectl get application frontend-dev -n argocd -o yaml

# Check sync status for specific app
kubectl get applications -n argocd -l team=frontend
```

Or use the ArgoCD UI: http://localhost:30082

## Troubleshooting

### Application Not Created
- Verify directory exists in Git: `ls k8s/team-apps/`
- Check ApplicationSet status: `kubectl get applicationset team-apps -n argocd -o yaml`
- View ApplicationSet logs: `kubectl logs -n argocd -l app.kubernetes.io/name=argocd-applicationset-controller`

### Application Sync Failed
- Check application status: `kubectl get application frontend-dev -n argocd`
- View sync errors: `kubectl describe application frontend-dev -n argocd`
- Check Helm chart validity: `helm lint k8s/team-apps/frontend`

### HTTPRoute Not Working
- Verify Gateway exists: `kubectl get gateway -n istio-system`
- Check HTTPRoute: `kubectl get httproute -n frontend`
- Test routing: `curl -v -H "Host: dev.cuddly-disco.ai.localhost" http://localhost:3000/`

## Future Enhancements

Planned features:
- Per-team version pinning via `config.yaml`
- Auto-migration to Helm chart registry
- Team-specific resource quotas
- Custom domain support per team
- Blue/green deployment strategy
- Progressive delivery with rollout analysis
