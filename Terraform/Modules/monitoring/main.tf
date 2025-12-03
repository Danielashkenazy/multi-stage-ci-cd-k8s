resource "helm_release" "prometheus" {
  name             = "prometheus"
  namespace        = "monitoring"
  create_namespace = true
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"

  values = [yamlencode({
    alertmanager = {
      enabled = false
    }
    pushgateway = {
      enabled = false
    }
    server = {
      persistentVolume = {
        enabled = false
      }
    }
  })]
}