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

# Register dev cluster with management ArgoCD
module "register_dev_cluster" {
  source = "../modules/argocd-cluster-registration"

  # Only register if dev cluster exists (state file has outputs)
  count = try(data.terraform_remote_state.dev.outputs.cluster_endpoint, null) != null ? 1 : 0

  cluster_name           = data.terraform_remote_state.dev.outputs.cluster_name
  cluster_endpoint       = data.terraform_remote_state.dev.outputs.cluster_endpoint
  cluster_ca_certificate = data.terraform_remote_state.dev.outputs.cluster_ca_certificate
  client_certificate     = data.terraform_remote_state.dev.outputs.client_certificate
  client_key             = data.terraform_remote_state.dev.outputs.client_key

  depends_on = [module.argocd]
}

# Register prod cluster with management ArgoCD
module "register_prod_cluster" {
  source = "../modules/argocd-cluster-registration"

  # Only register if prod cluster exists (state file has outputs)
  count = try(data.terraform_remote_state.prod.outputs.cluster_endpoint, null) != null ? 1 : 0

  cluster_name           = data.terraform_remote_state.prod.outputs.cluster_name
  cluster_endpoint       = data.terraform_remote_state.prod.outputs.cluster_endpoint
  cluster_ca_certificate = data.terraform_remote_state.prod.outputs.cluster_ca_certificate
  client_certificate     = data.terraform_remote_state.prod.outputs.client_certificate
  client_key             = data.terraform_remote_state.prod.outputs.client_key

  depends_on = [module.argocd]
}
