
resource "azurerm_resource_group" "rg" {
  location = var.resource_group_location
  name     = var.resource_group_name
}


resource "random_pet" "azurerm_kubernetes_cluster_dns_prefix" {
  prefix = "dns"
}

resource "azurerm_kubernetes_cluster" "k8s" {
  location            = azurerm_resource_group.rg.location
  name                = var.cluster_name
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = random_pet.azurerm_kubernetes_cluster_dns_prefix.id
  sku_tier            = "Free"
  private_cluster_enabled             = false
  private_cluster_public_fqdn_enabled = false
  oidc_issuer_enabled                 = true


  identity {
    type = "SystemAssigned"
  }

  default_node_pool {
    name                  = "agentpool"
    vm_size               = "Standard_D2s_v3"
    node_count            = var.node_count
    enable_node_public_ip = false
  }
  linux_profile {
    admin_username = var.username

    ssh_key {
      key_data = azapi_resource_action.ssh_public_key_gen.output.publicKey
    }
  }
  network_profile {
    network_plugin    = "kubenet"
    load_balancer_sku = "standard"
  }
}


