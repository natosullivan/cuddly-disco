resource "kubectl_manifest" "team_apps" {
  yaml_body = file(var.team_apps_file)

  depends_on = [var.argocd_ready]
}

resource "kubectl_manifest" "team_apps_branches" {
  yaml_body = file(var.team_apps_branches_file)

  depends_on = [var.argocd_ready]
}
