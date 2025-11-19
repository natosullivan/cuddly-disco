#!/bin/bash

# Kubernetes helper functions for smoke tests
# Provides reusable functions for common K8s operations

# Wait for pods in a namespace to be Ready
# Usage: wait_for_pods <namespace> <timeout_seconds>
wait_for_pods() {
    local namespace=$1
    local timeout=${2:-60}
    local elapsed=0
    local interval=2

    echo "Waiting for pods in namespace '$namespace' to be Ready (timeout: ${timeout}s)..."

    while [ $elapsed -lt $timeout ]; do
        # Get count of pods that are NOT ready (1/1, 2/2, etc.)
        local not_ready
        not_ready=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null | grep -v "Running" | wc -l)

        if [ "$not_ready" -eq 0 ]; then
            # Check if there are any pods at all
            local total_pods
            total_pods=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null | wc -l)

            if [ "$total_pods" -gt 0 ]; then
                echo "All pods in namespace '$namespace' are Ready"
                return 0
            fi
        fi

        sleep $interval
        elapsed=$((elapsed + interval))
    done

    echo "Timeout waiting for pods in namespace '$namespace'"
    kubectl get pods -n "$namespace" 2>/dev/null || echo "No pods found"
    return 1
}

# Check if namespace exists
# Usage: check_namespace <namespace>
check_namespace() {
    local namespace=$1

    if kubectl get namespace "$namespace" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Get count of pods in a specific state
# Usage: get_pod_count_by_status <namespace> <status>
# Status examples: Running, Pending, Failed, CrashLoopBackOff
get_pod_count_by_status() {
    local namespace=$1
    local status=$2

    kubectl get pods -n "$namespace" --no-headers 2>/dev/null | grep "$status" | wc -l
}

# Check if all nodes are Ready
# Returns 0 if all nodes are Ready, 1 otherwise
check_all_nodes_ready() {
    local not_ready_count
    not_ready_count=$(kubectl get nodes --no-headers 2>/dev/null | grep -v " Ready" | wc -l)

    if [ "$not_ready_count" -eq 0 ]; then
        return 0
    else
        echo "Found $not_ready_count nodes that are not Ready"
        kubectl get nodes 2>/dev/null
        return 1
    fi
}

# Get pod count in namespace
# Usage: get_pod_count <namespace>
get_pod_count() {
    local namespace=$1

    kubectl get pods -n "$namespace" --no-headers 2>/dev/null | wc -l
}

# Check if a specific resource exists
# Usage: check_resource_exists <resource_type> <resource_name> <namespace>
# Example: check_resource_exists "deployment" "frontend" "default"
check_resource_exists() {
    local resource_type=$1
    local resource_name=$2
    local namespace=${3:-""}

    local ns_flag=""
    if [ -n "$namespace" ]; then
        ns_flag="-n $namespace"
    fi

    if kubectl get "$resource_type" "$resource_name" $ns_flag &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Wait for a resource to be ready
# Usage: wait_for_resource_ready <resource_type> <resource_name> <namespace> <timeout_seconds>
wait_for_resource_ready() {
    local resource_type=$1
    local resource_name=$2
    local namespace=$3
    local timeout=${4:-60}
    local elapsed=0
    local interval=2

    echo "Waiting for $resource_type/$resource_name in namespace '$namespace' to be ready (timeout: ${timeout}s)..."

    while [ $elapsed -lt $timeout ]; do
        if kubectl get "$resource_type" "$resource_name" -n "$namespace" &>/dev/null; then
            # Check readiness based on resource type
            case $resource_type in
                "deployment")
                    local ready
                    ready=$(kubectl get deployment "$resource_name" -n "$namespace" -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null)
                    if [ "$ready" = "True" ]; then
                        echo "$resource_type/$resource_name is ready"
                        return 0
                    fi
                    ;;
                *)
                    # For other resources, just check existence
                    echo "$resource_type/$resource_name exists"
                    return 0
                    ;;
            esac
        fi

        sleep $interval
        elapsed=$((elapsed + interval))
    done

    echo "Timeout waiting for $resource_type/$resource_name"
    return 1
}

# Check if Gateway resource is Ready (Gateway API)
# Usage: check_gateway_ready <gateway_name> <namespace>
check_gateway_ready() {
    local gateway_name=$1
    local namespace=$2

    # Check if Gateway exists
    if ! kubectl get gateway "$gateway_name" -n "$namespace" &>/dev/null; then
        echo "Gateway $gateway_name not found in namespace $namespace"
        return 1
    fi

    # Check Gateway status conditions
    local programmed
    programmed=$(kubectl get gateway "$gateway_name" -n "$namespace" -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}' 2>/dev/null)

    if [ "$programmed" = "True" ]; then
        return 0
    else
        echo "Gateway $gateway_name is not Programmed (status: $programmed)"
        kubectl get gateway "$gateway_name" -n "$namespace" -o yaml 2>/dev/null
        return 1
    fi
}

# Get the kubeconfig context for a cluster
# Usage: get_cluster_context <cluster_name>
get_cluster_context() {
    local cluster_name=$1

    # For kind clusters, context is usually kind-<cluster-name>
    if kubectl config get-contexts -o name | grep -q "kind-${cluster_name}"; then
        echo "kind-${cluster_name}"
        return 0
    elif kubectl config get-contexts -o name | grep -q "$cluster_name"; then
        echo "$cluster_name"
        return 0
    else
        echo "Context for cluster '$cluster_name' not found" >&2
        return 1
    fi
}

# Switch to cluster context
# Usage: switch_cluster_context <cluster_name>
switch_cluster_context() {
    local cluster_name=$1

    # First, try to use the kubeconfig file directly (Terraform pattern)
    # Format: ~/.kube/kind-<cluster-name>
    local kubeconfig_file="$HOME/.kube/kind-${cluster_name}"
    if [ -f "$kubeconfig_file" ]; then
        export KUBECONFIG="$kubeconfig_file"
        # Verify we can connect
        if kubectl cluster-info &>/dev/null; then
            return 0
        fi
    fi

    # Fallback: try to switch context in default kubeconfig
    local context
    context=$(get_cluster_context "$cluster_name")
    if [ $? -eq 0 ]; then
        export KUBECONFIG="$HOME/.kube/config"
        kubectl config use-context "$context" &>/dev/null
        return 0
    else
        return 1
    fi
}

# Wait for ArgoCD application to sync
# Usage: wait_for_argocd_sync <app_name> <timeout_seconds> [namespace]
wait_for_argocd_sync() {
    local app_name=$1
    local timeout=${2:-300}
    local namespace=${3:-"argocd"}
    local elapsed=0
    local interval=5

    echo "Waiting for ArgoCD application '$app_name' to sync (timeout: ${timeout}s)..."

    while [ $elapsed -lt $timeout ]; do
        # Check if application exists
        if ! kubectl get application "$app_name" -n "$namespace" &>/dev/null; then
            echo "Application '$app_name' not found in namespace '$namespace'"
            sleep $interval
            elapsed=$((elapsed + interval))
            continue
        fi

        # Check sync status
        local sync_status
        sync_status=$(kubectl get application "$app_name" -n "$namespace" -o jsonpath='{.status.sync.status}' 2>/dev/null)

        if [ "$sync_status" = "Synced" ]; then
            echo "Application '$app_name' is Synced"
            return 0
        fi

        sleep $interval
        elapsed=$((elapsed + interval))
    done

    echo "Timeout waiting for application '$app_name' to sync"
    kubectl get application "$app_name" -n "$namespace" -o yaml 2>/dev/null || echo "Application not found"
    return 1
}

# Check ArgoCD application health
# Usage: check_application_health <app_name> [namespace]
check_application_health() {
    local app_name=$1
    local namespace=${2:-"argocd"}

    # Check if application exists
    if ! kubectl get application "$app_name" -n "$namespace" &>/dev/null; then
        echo "Application '$app_name' not found in namespace '$namespace'"
        return 1
    fi

    # Check health status
    local health_status
    health_status=$(kubectl get application "$app_name" -n "$namespace" -o jsonpath='{.status.health.status}' 2>/dev/null)

    if [ "$health_status" = "Healthy" ]; then
        return 0
    else
        echo "Application '$app_name' is not Healthy (status: $health_status)"
        kubectl get application "$app_name" -n "$namespace" -o jsonpath='{.status.health}' 2>/dev/null
        echo ""
        return 1
    fi
}

# Test HTTP endpoint
# Usage: test_http_endpoint <url> <expected_status> [host_header]
test_http_endpoint() {
    local url=$1
    local expected_status=${2:-200}
    local host_header=$3

    local curl_opts="-s -o /dev/null -w %{http_code}"
    if [ -n "$host_header" ]; then
        curl_opts="$curl_opts -H Host:$host_header"
    fi

    # Add timeout to prevent hanging
    curl_opts="$curl_opts --connect-timeout 10 --max-time 30"

    local actual_status
    actual_status=$(curl $curl_opts "$url" 2>/dev/null)
    local curl_exit=$?

    if [ $curl_exit -ne 0 ]; then
        echo "curl failed with exit code $curl_exit"
        return 1
    fi

    if [ "$actual_status" = "$expected_status" ]; then
        return 0
    else
        echo "Expected HTTP $expected_status but got $actual_status from $url"
        return 1
    fi
}
