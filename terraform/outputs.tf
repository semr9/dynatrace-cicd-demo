# Terraform Outputs

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "acr_login_server" {
  description = "ACR login server URL"
  value       = azurerm_container_registry.acr.login_server
}

output "acr_admin_username" {
  description = "ACR admin username"
  value       = azurerm_container_registry.acr.admin_username
  sensitive   = true
}

output "acr_admin_password" {
  description = "ACR admin password"
  value       = azurerm_container_registry.acr.admin_password
  sensitive   = true

}

output "aks_cluster_name" {
  description = "AKS cluster name"
  value       = azurerm_kubernetes_cluster.aks.name
}

output "aks_cluster_id" {
  description = "AKS cluster ID"
  value       = azurerm_kubernetes_cluster.aks.id
}

output "aks_kube_config" {
  description = "AKS kubeconfig (use: terraform output -raw aks_kube_config > ~/.kube/config)"
  value       = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive   = true
}

output "application_url_command" {
  description = "Command to get application URL (after ArgoCD deploys it)"
  value       = "kubectl get service frontend-service -n ${kubernetes_namespace.app.metadata[0].name} -o jsonpath='{.status.loadBalancer.ingress[0].ip}'"
}

output "kubernetes_namespace" {
  description = "Kubernetes namespace"
  value       = kubernetes_namespace.app.metadata[0].name
}

output "get_aks_credentials_command" {
  description = "Command to get AKS credentials"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${azurerm_kubernetes_cluster.aks.name}"
}

output "useful_commands" {
  description = "Useful kubectl commands"
  value = {
    get_pods     = "kubectl get pods -n ${kubernetes_namespace.app.metadata[0].name}"
    get_services = "kubectl get services -n ${kubernetes_namespace.app.metadata[0].name}"
    get_logs     = "kubectl logs <pod-name> -n ${kubernetes_namespace.app.metadata[0].name}"
    describe_pod = "kubectl describe pod <pod-name> -n ${kubernetes_namespace.app.metadata[0].name}"
  }
}

