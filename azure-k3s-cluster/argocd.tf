resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }

}

resource "kubernetes_namespace" "external_secrets" {
  metadata {
    name = "external-secrets"
  }
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = kubernetes_namespace.argocd.metadata[0].name
  create_namespace = false
  timeout          = 1200
  values = [
    yamlencode({
      configs = {
        cm = {
          "accounts.image-updater" = "apiKey, login"
        }
        rbac = {
          "policy.csv" = <<-EOT
p, role:image-updater, applications, get, gitops-galaxy/*, allow
p, role:image-updater, applications, update, gitops-galaxy/*, allow
p, role:image-updater, applications, action/*, gitops-galaxy/*, allow
g, image-updater, role:image-updater
EOT
        }
      }
    })
  ]

}


