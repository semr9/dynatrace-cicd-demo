# ArgoCD Installation on AKS

# Install ArgoCD using external PowerShell script
resource "null_resource" "install_argocd" {
  triggers = {
    aks_id = azurerm_kubernetes_cluster.aks.id
  }

  provisioner "local-exec" {
    command     = <<-EOT
      & "${path.module}/../scripts/install-argocd.ps1"
    EOT
    interpreter = ["PowerShell", "-Command"]
  }

  depends_on = [
    azurerm_kubernetes_cluster.aks,
    local_file.kubeconfig
  ]
}
