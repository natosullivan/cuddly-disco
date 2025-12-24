variable "team_apps_file" {
  description = "Path to team-apps ApplicationSet YAML file"
  type        = string
}

variable "team_apps_branches_file" {
  description = "Path to team-apps-branches ApplicationSet YAML file"
  type        = string
}

variable "argocd_ready" {
  description = "Dependency to ensure ArgoCD is ready before deploying ApplicationSets"
  type        = any
  default     = null
}
