output "aks_name" {
  value = azurerm_kubernetes_cluster.main.name
}

output "aks_resource_group" {
  value = azurerm_resource_group.main.name
}

output "acr_login_server" {
  value = azurerm_container_registry.main.login_server
}

output "jump_public_ip" {
  value = azurerm_public_ip.jump.ip_address
}

output "app_mi_client_id" {
  description = "Client ID for the app managed identity — set as workloadIdentity.clientId in Helm"
  value       = azurerm_user_assigned_identity.app.client_id
}

output "oidc_issuer_url" {
  value = azurerm_kubernetes_cluster.main.oidc_issuer_url
}
