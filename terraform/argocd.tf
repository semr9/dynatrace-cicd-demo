# ArgoCD Installation on AKS

# Install ArgoCD using Helm
resource "null_resource" "install_argocd" {
  triggers = {
    aks_id = azurerm_kubernetes_cluster.aks.id
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      # Create argocd namespace
      kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
      
      # Install ArgoCD
      kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
      
      # Wait for ArgoCD to be ready
      kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
      
      echo "ArgoCD installed successfully!"
      echo "Get admin password with: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
    EOT
  }
  
  depends_on = [
    azurerm_kubernetes_cluster.aks,
    local_file.kubeconfig
  ]
}

# Optional: Expose ArgoCD with LoadBalancer
resource "kubernetes_service" "argocd_server_lb" {
  metadata {
    name      = "argocd-server-lb"
    namespace = "argocd"
    labels = {
      app = "argocd-server"
    }
  }
  
  spec {
    type = "LoadBalancer"
    
    selector = {
      "app.kubernetes.io/name" = "argocd-server"
    }
    
    port {
      name        = "http"
      port        = 80
      target_port = 8080
      protocol    = "TCP"
    }
    
    port {
      name        = "https"
      port        = 443
      target_port = 8080
      protocol    = "TCP"
    }
  }
  
  depends_on = [null_resource.install_argocd]
}

# Get ArgoCD initial admin password
data "kubernetes_secret" "argocd_admin_password" {
  metadata {
    name      = "argocd-initial-admin-secret"
    namespace = "argocd"
  }
  
  depends_on = [null_resource.install_argocd]
}


