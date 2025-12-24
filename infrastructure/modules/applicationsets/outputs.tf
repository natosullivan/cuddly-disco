output "team_apps_id" {
  description = "ID of the team-apps ApplicationSet resource"
  value       = kubectl_manifest.team_apps.id
}

output "team_apps_branches_id" {
  description = "ID of the team-apps-branches ApplicationSet resource"
  value       = kubectl_manifest.team_apps_branches.id
}
