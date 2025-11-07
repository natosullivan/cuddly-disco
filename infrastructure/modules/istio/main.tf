# Create istio-system namespace
resource "kubernetes_namespace" "istio_system" {
  count = var.create_namespace ? 1 : 0

  metadata {
    name = var.namespace
  }
}

# Install Gateway API CRDs
# Using kubectl apply to install CRDs from official Gateway API project
resource "null_resource" "gateway_api_crds" {
  provisioner "local-exec" {
    command = "kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/${var.gateway_api_version}/standard-install.yaml"
    environment = {
      KUBECONFIG = var.kubeconfig_path
    }
  }

  depends_on = [kubernetes_namespace.istio_system]
}

# Install Istio Base (CRDs and cluster-wide resources)
resource "helm_release" "istio_base" {
  name       = "istio-base"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "base"
  version    = var.istio_base_version
  namespace  = var.namespace

  depends_on = [
    kubernetes_namespace.istio_system,
    null_resource.gateway_api_crds
  ]

  wait          = true
  wait_for_jobs = true
  timeout       = 600
}

# Install Istiod (control plane)
resource "helm_release" "istiod" {
  name       = "istiod"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "istiod"
  version    = var.istiod_version
  namespace  = var.namespace

  # Minimal profile - Gateway only, no service mesh features
  set {
    name  = "pilot.env.PILOT_ENABLE_GATEWAY_API"
    value = "true"
  }

  set {
    name  = "pilot.env.PILOT_ENABLE_GATEWAY_API_STATUS"
    value = "true"
  }

  set {
    name  = "pilot.env.PILOT_ENABLE_GATEWAY_API_DEPLOYMENT_CONTROLLER"
    value = "true"
  }

  depends_on = [helm_release.istio_base]

  wait          = true
  wait_for_jobs = true
  timeout       = 600
}

# Create Gateway manifest file
resource "local_file" "gateway_manifest" {
  filename = "${path.module}/gateway-${var.gateway_name}.yaml"
  content  = <<-EOT
    apiVersion: gateway.networking.k8s.io/v1
    kind: Gateway
    metadata:
      name: ${var.gateway_name}
      namespace: ${var.namespace}
      annotations:
        networking.istio.io/service-type: NodePort
    spec:
      gatewayClassName: istio
      listeners:
      - name: http
        protocol: HTTP
        port: 80
        hostname: ${var.gateway_hostname}
        allowedRoutes:
          namespaces:
            from: All
  EOT
}

# Create Gateway resource using kubectl
resource "null_resource" "gateway" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${local_file.gateway_manifest.filename}"
    environment = {
      KUBECONFIG = var.kubeconfig_path
    }
  }

  depends_on = [
    helm_release.istiod,
    null_resource.gateway_api_crds,
    local_file.gateway_manifest
  ]

  # Recreate if gateway hostname or manifest changes
  triggers = {
    gateway_hostname = var.gateway_hostname
    manifest_content = local_file.gateway_manifest.content
  }
}

# Patch the Gateway service to use NodePort 30001
resource "null_resource" "gateway_nodeport_patch" {
  provisioner "local-exec" {
    command = "sleep 15 && kubectl patch service ${var.gateway_name}-istio -n ${var.namespace} --type=json -p='[{\"op\":\"replace\",\"path\":\"/spec/ports/0/nodePort\",\"value\":30001}]'"
    environment = {
      KUBECONFIG = var.kubeconfig_path
    }
  }

  depends_on = [null_resource.gateway]

  triggers = {
    gateway_id = null_resource.gateway.id
  }
}
