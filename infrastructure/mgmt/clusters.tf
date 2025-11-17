# Data source to read ArgoCD admin password
data "kubernetes_secret" "argocd_admin" {
  metadata {
    name      = "argocd-initial-admin-secret"
    namespace = "argocd"
  }

  depends_on = [module.argocd]
}

# Data sources to read dev and prod cluster Terraform outputs
# These read the Terraform state from the dev and prod directories

data "terraform_remote_state" "dev" {
  backend = "local"

  config = {
    path = "${path.module}/../dev/terraform.tfstate"
  }
}

data "terraform_remote_state" "prod" {
  backend = "local"

  config = {
    path = "${path.module}/../prod/terraform.tfstate"
  }
}

# Register dev cluster with management ArgoCD using ArgoCD provider
resource "argocd_cluster" "dev" {
  # Only register if dev cluster exists (state file has outputs)
  count = try(data.terraform_remote_state.dev.outputs.cluster_endpoint, null) != null ? 1 : 0

  server = data.terraform_remote_state.dev.outputs.cluster_endpoint_internal
  name   = data.terraform_remote_state.dev.outputs.cluster_name

  config {
    tls_client_config {
      ca_data   = data.terraform_remote_state.dev.outputs.cluster_ca_certificate
      cert_data = data.terraform_remote_state.dev.outputs.client_certificate
      key_data  = data.terraform_remote_state.dev.outputs.client_key
    }
  }

  depends_on = [module.argocd]
}

# Register prod cluster with management ArgoCD using ArgoCD provider
resource "argocd_cluster" "prod" {
  # Only register if prod cluster exists (state file has outputs)
  count = try(data.terraform_remote_state.prod.outputs.cluster_endpoint, null) != null ? 1 : 0

  server = data.terraform_remote_state.prod.outputs.cluster_endpoint_internal
  name   = data.terraform_remote_state.prod.outputs.cluster_name

  config {
    tls_client_config {
      ca_data   = data.terraform_remote_state.prod.outputs.cluster_ca_certificate
      cert_data = data.terraform_remote_state.prod.outputs.client_certificate
      key_data  = data.terraform_remote_state.prod.outputs.client_key
    }
  }

  depends_on = [module.argocd]
}
