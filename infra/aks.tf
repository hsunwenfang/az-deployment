resource "azurerm_kubernetes_cluster" "main" {
  name                    = "hsunaks"
  location                = azurerm_resource_group.main.location
  resource_group_name     = azurerm_resource_group.main.name
  dns_prefix              = "hsunaks"
  private_cluster_enabled = true

  # Workload Identity requires OIDC issuer
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks.id]
  }

  # The "app" MI serves as the kubelet identity so nodes can pull from ACR
  kubelet_identity {
    user_assigned_identity_id = azurerm_user_assigned_identity.app.id
    client_id                 = azurerm_user_assigned_identity.app.client_id
    object_id                 = azurerm_user_assigned_identity.app.principal_id
  }

  # System nodepool — labeled agent
  default_node_pool {
    name           = "agent"
    node_count     = 2
    vm_size        = "Standard_D2s_v3"
    vnet_subnet_id = azurerm_subnet.aks.id
    node_labels    = { nodepool = "agent" }
  }

  # API server VNet integration: injects the API server into apiserver-subnet
  api_server_access_profile {
    subnet_id                = azurerm_subnet.apiserver.id
    vnet_integration_enabled = true
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
  }
}

# ── Additional nodepools ──────────────────────────────────────────────────────

resource "azurerm_kubernetes_cluster_node_pool" "app" {
  name                  = "app"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = "Standard_D2s_v3"
  node_count            = 2
  vnet_subnet_id        = azurerm_subnet.aks.id
  node_labels           = { nodepool = "app" }
}

resource "azurerm_kubernetes_cluster_node_pool" "gh" {
  name                  = "gh"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = "Standard_D2s_v3"
  node_count            = 2
  vnet_subnet_id        = azurerm_subnet.aks.id
  node_labels           = { nodepool = "gh" }
}
