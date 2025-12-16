# Manual Branch Deployment Guide

This guide documents the manual process for deploying feature branches to the dev environment using the branch-based versioning system.

## Overview

The branch deployment system allows developers to deploy their feature branch code to the dev cluster and access it via the `X-Version` header. This enables testing branch code without affecting the default v1 or v2 deployments.

## Architecture

### Directory Structure

```
k8s/team-apps/
├── frontend/
│   ├── branches/
│   │   └── dev-test-branch.yaml      # Branch-specific values
│   ├── TEMPLATE-values-dev.yaml      # Template for creating new branch files
│   ├── values.yaml                   # Base values
│   ├── values-dev.yaml                # Static dev v1
│   └── values-dev-v2.yaml             # Static dev v2
└── backend/
    ├── branches/
    ├── TEMPLATE-values-dev.yaml
    ├── values.yaml
    ├── values-dev.yaml
    └── values-dev-v2.yaml
```

### How It Works

1. **Git File Generator**: The `team-apps-branches` ApplicationSet uses ArgoCD's Git file generator to discover values files matching the pattern `k8s/team-apps/*/branches/dev-*.yaml`

2. **Automatic Application Creation**: When a matching file is found, ArgoCD automatically creates an Application with the name format: `{app}-dev-{branch-name}`

3. **Deployment**: The Application deploys to the dev cluster using the branch-specific values

4. **Access**: The deployment is accessible via the Istio Gateway using the `X-Version: {branch-name}` header

5. **Cleanup**: When the values file is deleted, ArgoCD automatically prunes all Kubernetes resources

## Manual Deployment Process

### Step 1: Create Branch Values File

1. Navigate to the app's `branches/` directory:
   ```bash
   cd k8s/team-apps/frontend/branches/
   ```

2. Copy the template file:
   ```bash
   cp ../TEMPLATE-values-dev.yaml dev-my-feature.yaml
   ```

3. Edit the new file and update the following fields:
   ```yaml
   # Version configuration
   version:
     name: "my-feature"  # CHANGE THIS - must match filename
     isDefault: false

   # Image configuration
   image:
     repository: ghcr.io/natosullivan/cuddly-disco/frontend
     tag: "v1.3.0"  # CHANGE THIS to your branch image tag (if available)

   # Frontend configuration
   config:
     location: "Development (branch: my-feature)"  # CHANGE THIS
     backendUrl: "http://backend-service.backend.svc.cluster.local:5000"
   ```

### Step 2: Commit and Push

```bash
git add k8s/team-apps/frontend/branches/dev-my-feature.yaml
git commit -m "feat: Add branch deployment for my-feature"
git push
```

### Step 3: Wait for ArgoCD Discovery

ArgoCD's Git file generator polls the repository every 3 minutes by default.

**Monitor the ApplicationSet:**
```bash
kubectl get applicationset team-apps-branches -n argocd --context kind-kind-mgmt
```

**Wait for Application creation:**
```bash
kubectl get applications -n argocd -l type=branch-version --context kind-kind-mgmt
```

You should see an application named `frontend-dev-my-feature`.

### Step 4: Verify Deployment

**Check Application Status:**
```bash
kubectl get application frontend-dev-my-feature -n argocd --context kind-kind-mgmt
```

Wait for `SYNC STATUS: Synced` and `HEALTH STATUS: Healthy`.

**Check Resources in Dev Cluster:**
```bash
# Switch to dev cluster
export KUBECONFIG=~/.kube/kind-kind-dev

# Check pod
kubectl get pods -n frontend | grep my-feature

# Check service
kubectl get service -n frontend | grep my-feature

# Check HTTPRoute
kubectl get httproute -n frontend | grep my-feature
```

Expected resources:
- Pod: `frontend-dev-my-feature-frontend-app-xxxxx`
- Service: `frontend-dev-my-feature-frontend-app`
- HTTPRoute: `frontend-dev-my-feature-frontend-app`

### Step 5: Test Access

**Using curl:**
```bash
curl -H "Host: dev.cuddly-disco.ai.localhost" \
     -H "X-Version: my-feature" \
     http://localhost:3000
```

**Using browser with ModHeader extension:**
1. Install ModHeader extension
2. Add request header: `X-Version: my-feature`
3. Navigate to: http://dev.cuddly-disco.ai.localhost:3000

You should see: "For all the SRE/DevOps/Platform engineers out there, here are some kind words from **Development (branch: my-feature)**"

### Step 6: Cleanup (When Done)

**Delete the values file:**
```bash
git rm k8s/team-apps/frontend/branches/dev-my-feature.yaml
git commit -m "cleanup: Remove my-feature branch deployment"
git push
```

**Verify cleanup:**
```bash
# Wait ~3 minutes for ArgoCD to detect deletion
sleep 180

# Check Application is gone
kubectl get applications -n argocd -l type=branch-version --context kind-kind-mgmt

# Check resources are pruned
kubectl get pods,service,httproute -n frontend --context kind-kind-dev | grep my-feature
```

All resources should be automatically deleted within 2 minutes of ArgoCD detecting the file deletion.

## Testing Checklist

Use this checklist to verify your branch deployment:

- [ ] Values file created in correct location (`k8s/team-apps/{app}/branches/dev-{branch}.yaml`)
- [ ] Values file committed and pushed to GitHub
- [ ] ApplicationSet discovered file (check `kubectl get applicationset team-apps-branches -n argocd`)
- [ ] Application created with correct name (`{app}-dev-{branch}`)
- [ ] Application shows `SYNC STATUS: Synced`
- [ ] Application shows `HEALTH STATUS: Healthy`
- [ ] Pod is running in dev cluster
- [ ] Service created with correct name
- [ ] HTTPRoute created and configured
- [ ] Accessible via `X-Version: {branch}` header
- [ ] Frontend displays correct branch name
- [ ] Frontend connects to backend (if configured)
- [ ] Cleanup: Values file deletion triggers automatic pruning
- [ ] Cleanup: All resources removed within 2 minutes

## Troubleshooting Guide

### Issue: Application Not Created After 3+ Minutes

**Symptoms:** Values file pushed but no Application appears in ArgoCD.

**Checks:**
1. Verify file is in correct location:
   ```bash
   ls -la k8s/team-apps/*/branches/dev-*.yaml
   ```

2. Check file naming matches pattern:
   - Must be in `branches/` subdirectory
   - Must start with `dev-`
   - Must end with `.yaml`
   - Must NOT start with `TEMPLATE-`

3. Check ApplicationSet status:
   ```bash
   kubectl get applicationset team-apps-branches -n argocd -o yaml | grep -A 10 status
   ```

4. Look for errors in ApplicationSet conditions:
   ```bash
   kubectl get applicationset team-apps-branches -n argocd -o jsonpath='{.status.conditions}' | jq
   ```

**Solution:** Force ApplicationSet refresh:
```bash
kubectl patch applicationset team-apps-branches -n argocd \
  --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"true"}}}'
```

### Issue: Application Shows OutOfSync

**Symptoms:** Application created but stuck in `OutOfSync` status.

**Checks:**
1. View Application details:
   ```bash
   kubectl describe application frontend-dev-{branch} -n argocd
   ```

2. Check sync status:
   ```bash
   kubectl get application frontend-dev-{branch} -n argocd -o jsonpath='{.status.sync}'
   ```

**Solution:** Trigger manual sync:
```bash
kubectl patch application frontend-dev-{branch} -n argocd \
  --type merge \
  -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'
```

### Issue: Pod Not Starting

**Symptoms:** Application synced but pod shows `ImagePullBackOff`, `CrashLoopBackOff`, or `Pending`.

**Checks:**
1. Check pod status:
   ```bash
   kubectl get pods -n frontend -l app=frontend-dev-{branch}-frontend-app
   ```

2. Check pod events:
   ```bash
   kubectl describe pod -n frontend -l app=frontend-dev-{branch}-frontend-app
   ```

3. Check pod logs:
   ```bash
   kubectl logs -n frontend -l app=frontend-dev-{branch}-frontend-app
   ```

**Common Issues:**
- **ImagePullBackOff**: Image tag doesn't exist in GHCR
  - Solution: Use existing tag (e.g., `v1.3.0`) or build and publish your branch image
- **CrashLoopBackOff**: Application error on startup
  - Solution: Check logs for error messages
- **Pending**: Resource constraints
  - Solution: Check cluster resources or reduce resource requests in values file

### Issue: Cannot Access via X-Version Header

**Symptoms:** Deployment successful but curl returns 404 or wrong version.

**Checks:**
1. Verify HTTPRoute exists:
   ```bash
   kubectl get httproute frontend-dev-{branch}-frontend-app -n frontend -o yaml
   ```

2. Check HTTPRoute has correct header match:
   ```yaml
   matches:
   - headers:
     - name: X-Version
       value: {branch}
   ```

3. Verify Gateway is ready:
   ```bash
   kubectl get gateway cuddly-disco-gateway -n istio-system
   ```

4. Test without header (should get v1):
   ```bash
   curl -H "Host: dev.cuddly-disco.ai.localhost" http://localhost:3000
   ```

5. Test with header:
   ```bash
   curl -H "Host: dev.cuddly-disco.ai.localhost" \
        -H "X-Version: {branch}" \
        http://localhost:3000
   ```

**Solution:** Ensure `version.name` in values file exactly matches the header value (case-sensitive, no spaces).

### Issue: Cleanup Not Working

**Symptoms:** Values file deleted but Application and resources still exist.

**Checks:**
1. Verify file is actually deleted from Git:
   ```bash
   git log --oneline --follow -- k8s/team-apps/*/branches/dev-{branch}.yaml
   ```

2. Check ApplicationSet reconciliation:
   ```bash
   kubectl get applicationset team-apps-branches -n argocd -o jsonpath='{.status}' | jq
   ```

**Solution 1:** Wait longer (up to 3 minutes for Git poll interval)

**Solution 2:** Force ApplicationSet refresh:
```bash
kubectl patch applicationset team-apps-branches -n argocd \
  --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"true"}}}'
```

**Solution 3:** Manual cleanup (emergency fallback):
```bash
# Delete Application (will trigger resource pruning)
kubectl delete application frontend-dev-{branch} -n argocd

# If resources still exist, delete manually
kubectl delete deployment,service,httproute -n frontend -l app=frontend-dev-{branch}-frontend-app
```

### Issue: Backend Connection Failed

**Symptoms:** Frontend displays "Unable to connect to backend service".

**Checks:**
1. Verify backend URL in values file:
   ```yaml
   config:
     backendUrl: "http://backend-service.backend.svc.cluster.local:5000"
   ```

2. Check backend service exists:
   ```bash
   kubectl get service backend-service -n backend
   ```

3. Test backend connectivity from frontend pod:
   ```bash
   POD=$(kubectl get pod -n frontend -l app=frontend-dev-{branch}-frontend-app -o jsonpath='{.items[0].metadata.name}')
   kubectl exec -n frontend $POD -- wget -O- http://backend-service.backend.svc.cluster.local:5000/health
   ```

**Solution:** Ensure backend service name matches the URL in values file.

## Advanced: Deploying Both Frontend and Backend

To deploy a full-stack feature (both frontend and backend):

1. Create backend branch values:
   ```bash
   cp k8s/team-apps/backend/TEMPLATE-values-dev.yaml \
      k8s/team-apps/backend/branches/dev-my-feature.yaml
   ```

2. Update backend values:
   ```yaml
   version:
     name: "my-feature"
   image:
     tag: "v1.2.0"  # Your backend branch image
   config:
     location: "Backend Dev (branch: my-feature)"
   ```

3. Update frontend values to use branch backend:
   ```yaml
   config:
     backendUrl: "http://backend-dev-my-feature-backend-app.backend.svc.cluster.local:5000"
   ```

4. Commit and push both files:
   ```bash
   git add k8s/team-apps/*/branches/dev-my-feature.yaml
   git commit -m "feat: Add full-stack deployment for my-feature"
   git push
   ```

Both applications will be created and can communicate with each other using the branch-specific backend URL.

## Key Concepts

### Naming Convention

- **Values file**: `dev-{branch-name}.yaml`
- **Application name**: `{app}-dev-{branch-name}`
- **Resources**: `{app}-dev-{branch-name}-{component}`

### Resource Limits

Branch deployments use reduced resource limits to allow multiple concurrent branches:

```yaml
resources:
  limits:
    cpu: 100m
    memory: 128Mi
  requests:
    cpu: 50m
    memory: 64Mi
```

### Default vs Branch Versions

- **Default versions** (v1, v2): Always accessible, no header required
- **Branch versions**: Require `X-Version` header, isolated from defaults

### ApplicationSet Synchronization

- **Poll Interval**: 3 minutes (ArgoCD default)
- **Manual Refresh**: Use annotation to force immediate refresh
- **Auto-sync**: Enabled - changes deploy automatically
- **Auto-prune**: Enabled - deletions cleanup automatically

## Next Steps

After mastering manual deployment:
- **Task 2**: Automate image building for branches
- **Task 3**: Auto-generate values files from CI
- **Task 4**: Auto-cleanup on PR merge/branch delete
- **Task 5**: PR comments with deployment status

## Resources

- **ApplicationSet**: `k8s/argocd-appsets/team-apps-branches.yaml`
- **Templates**: `k8s/team-apps/*/TEMPLATE-values-dev.yaml`
- **ArgoCD UI**: http://localhost:30080 (when mgmt cluster is running)
- **Main Documentation**: [KUBERNETES-DEPLOYMENT.md](./KUBERNETES-DEPLOYMENT.md)
