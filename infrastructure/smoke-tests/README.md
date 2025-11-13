# Kubernetes Cluster Smoke Tests

Fast, essential infrastructure smoke tests for validating Kubernetes cluster health after provisioning with Terraform.

## Overview

These smoke tests verify that your local Kind clusters are properly configured and core components are healthy. They are designed for **local development validation** and execute in under 2 minutes per cluster.

### What Gets Tested

**Test 01: Cluster Health** (`01-cluster-health.sh`)
- ✓ kubectl can connect to cluster
- ✓ All nodes are in Ready state
- ✓ kube-system pods are Running
- ✓ No pods in CrashLoopBackOff or Error state
- ✓ CoreDNS pods are healthy

**Test 02: ArgoCD Health** (`02-argocd-health.sh`)
- ✓ argocd namespace exists
- ✓ ArgoCD pods are Running and Ready
- ✓ ArgoCD UI is accessible on expected NodePort
- ✓ ArgoCD admin credentials are retrievable

**Test 03: Istio Health** (`03-istio-health.sh`) - dev/prod only
- ✓ istio-system namespace exists
- ✓ Istio control plane (istiod) is Running
- ✓ Gateway API CRDs are installed
- ✓ cuddly-disco Gateway is Programmed and Ready
- ✓ Istio ingress gateway service is accessible

## Prerequisites

- `kubectl` installed and configured
- One or more Kind clusters provisioned via Terraform:
  - `kind-dev` (port 30080)
  - `kind-prod` (port 30081)
  - `kind-mgmt` (port 30082)

## Usage

### Test a Single Cluster

```bash
# Test dev cluster
./infrastructure/smoke-tests/run-smoke-tests.sh kind-dev

# Test prod cluster
./infrastructure/smoke-tests/run-smoke-tests.sh kind-prod

# Test mgmt cluster
./infrastructure/smoke-tests/run-smoke-tests.sh kind-mgmt
```

### Test All Clusters

```bash
./infrastructure/smoke-tests/run-smoke-tests.sh all
```

### Typical Developer Workflow

```bash
# 1. Provision cluster with Terraform
cd infrastructure/dev
terraform apply

# 2. Run smoke tests to verify
cd ../..
./infrastructure/smoke-tests/run-smoke-tests.sh kind-dev

# 3. If tests pass, cluster is ready for use
```

## Test Output

Tests provide clear pass/fail indicators:

```
==========================================
Test 01: Cluster Health Check
Cluster: kind-dev
==========================================

Testing kubectl connectivity...
✓ kubectl can connect to cluster

Checking nodes...
✓ At least one node exists in cluster
✓ All nodes are in Ready state

Checking kube-system namespace...
✓ kube-system namespace exists
✓ At least one kube-system pod is Running

Checking for pods in error states...
✓ No pods in CrashLoopBackOff state
✓ No pods in Error state

==========================================
Test Summary: 01-cluster-health.sh
==========================================
Total:  7
Passed: 7
Failed: 0
==========================================
```

## Exit Codes

- `0` - All tests passed
- `1` - One or more tests failed

You can use this in scripts:

```bash
if ./infrastructure/smoke-tests/run-smoke-tests.sh kind-dev; then
    echo "Cluster is healthy, proceeding with deployment"
else
    echo "Cluster health check failed"
    exit 1
fi
```

## Cluster Configuration

The test runner knows about these clusters:

| Cluster | ArgoCD Port | Has Istio | Purpose |
|---------|-------------|-----------|---------|
| kind-dev | 30080 | Yes | Local development |
| kind-prod | 30081 | Yes | Production-like testing |
| kind-mgmt | 30082 | No | Management cluster (ArgoCD only) |

## Test Architecture

```
infrastructure/smoke-tests/
├── run-smoke-tests.sh              # Main test runner
├── lib/
│   ├── assertions.sh               # Test assertion functions
│   └── k8s-helpers.sh             # Kubernetes helper functions
├── tests/
│   ├── 01-cluster-health.sh       # Cluster health checks
│   ├── 02-argocd-health.sh        # ArgoCD health checks
│   └── 03-istio-health.sh         # Istio health checks (optional)
└── README.md                       # This file
```

### Helper Libraries

**assertions.sh** - Provides test assertion functions:
- `assert_success` - Assert command succeeds
- `assert_equals` - Assert string equality
- `assert_contains` - Assert substring match
- `assert_not_empty` - Assert value is not empty
- `assert_gte` - Assert number >= threshold
- `assert_http_200` - Assert HTTP 200 status
- `print_test_summary` - Print test results

**k8s-helpers.sh** - Provides Kubernetes utilities:
- `wait_for_pods` - Wait for pods to be Ready
- `check_namespace` - Check if namespace exists
- `get_pod_count_by_status` - Count pods by status
- `check_gateway_ready` - Check Gateway API status
- `switch_cluster_context` - Switch kubectl context

## Troubleshooting

### Tests fail with "context not found"

Make sure your cluster is provisioned and kubectl context exists:

```bash
kubectl config get-contexts
```

You should see contexts like `kind-kind-dev`, `kind-kind-prod`, etc.

### ArgoCD UI not accessible

Check that the NodePort service is configured correctly:

```bash
kubectl get svc -n argocd argocd-server
```

Verify port mappings in your Terraform configuration.

### Istio tests fail

If you're testing the mgmt cluster, Istio tests are automatically skipped (mgmt has no Istio).

For dev/prod clusters, verify Istio was installed via Terraform:

```bash
kubectl get pods -n istio-system
kubectl get gateway -n istio-system
```

### Pods stuck in Pending state

Check node resources and events:

```bash
kubectl get nodes
kubectl describe pod <pod-name> -n <namespace>
```

## Future Enhancements

These tests currently focus on infrastructure health. Future enhancements could include:

- End-to-end application flow testing (frontend → backend)
- ArgoCD sync behavior validation
- CI/CD integration for automated testing
- Performance benchmarks
- Chaos engineering scenarios

## Contributing

When adding new tests:

1. Create test script in `tests/` directory
2. Use helper functions from `lib/` for consistency
3. Follow naming convention: `NN-test-name.sh`
4. Update main runner if needed
5. Document new tests in this README
6. Keep tests fast (< 30 seconds per test)

## License

See repository root for license information.
