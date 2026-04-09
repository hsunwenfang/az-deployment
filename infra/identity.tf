# ── AKS control-plane identity ────────────────────────────────────────────────

resource "azurerm_user_assigned_identity" "aks" {
  name                = "aks-identity"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

# Allow AKS control plane to manage networking resources (LB, IPs, etc.)
resource "azurerm_role_assignment" "aks_network_contributor" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}

# ── App managed identity (workload identity + kubelet imagepull) ──────────────

resource "azurerm_user_assigned_identity" "app" {
  name                = "app"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

# AcrPull: allows kubelet nodes and the app to pull images from ACR
resource "azurerm_role_assignment" "app_acrpull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
}

# Reader on resource group: allows app.py to list ACR repositories
resource "azurerm_role_assignment" "app_reader" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
}

# Federated credential binding the "app" MI to serviceaccount:app/app in AKS
resource "azurerm_federated_identity_credential" "app" {
  name                = "app-federated"
  resource_group_name = azurerm_resource_group.main.name
  parent_id           = azurerm_user_assigned_identity.app.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.main.oidc_issuer_url
  subject             = "system:serviceaccount:app:app"
}
