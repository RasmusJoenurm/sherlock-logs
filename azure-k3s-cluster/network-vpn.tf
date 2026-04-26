locals {
  vpn_enabled = var.vpn_enabled
}

data "azurerm_virtual_network" "aks_vnet" {
  count               = local.vpn_enabled ? 1 : 0
  name                = var.aks_vnet_name
  resource_group_name = var.aks_vnet_resource_group_name
}

resource "azurerm_virtual_network" "vpn_vnet" {
  count               = local.vpn_enabled ? 1 : 0
  name                = "${var.cluster_name}-vpn-vnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = var.vpn_vnet_address_space
}

resource "azurerm_subnet" "vpn_gateway_subnet" {
  count                = local.vpn_enabled ? 1 : 0
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vpn_vnet[0].name
  address_prefixes     = var.vpn_gateway_subnet_prefixes
}

resource "azurerm_public_ip" "vpn_gateway_pip" {
  count               = local.vpn_enabled ? 1 : 0
  name                = "${var.cluster_name}-vpn-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_virtual_network_gateway" "p2s_gateway" {
  count               = local.vpn_enabled ? 1 : 0
  name                = "${var.cluster_name}-p2s-vpngw"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  type     = "Vpn"
  vpn_type = "RouteBased"
  sku      = var.vpn_gateway_sku

  ip_configuration {
    name                          = "vpngateway-ipconfig"
    public_ip_address_id          = azurerm_public_ip.vpn_gateway_pip[0].id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.vpn_gateway_subnet[0].id
  }

  vpn_client_configuration {
    address_space = var.vpn_client_address_space

    root_certificate {
      name             = "vpn-root"
      public_cert_data = var.vpn_root_cert_public_data
    }
  }
}

resource "azurerm_virtual_network_peering" "vpn_to_aks" {
  count                     = local.vpn_enabled ? 1 : 0
  name                      = "vpn-to-aks"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.vpn_vnet[0].name
  remote_virtual_network_id = data.azurerm_virtual_network.aks_vnet[0].id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_virtual_network_peering" "aks_to_vpn" {
  count                     = local.vpn_enabled ? 1 : 0
  name                      = "aks-to-vpn"
  resource_group_name       = var.aks_vnet_resource_group_name
  virtual_network_name      = var.aks_vnet_name
  remote_virtual_network_id = azurerm_virtual_network.vpn_vnet[0].id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

