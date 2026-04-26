locals {
  create_dns                 = var.enable_dns
  can_link_private_dns_vnet  = var.enable_private_dns_vnet_link && var.aks_vnet_name != "" && var.aks_vnet_resource_group_name != ""
}

resource "azurerm_dns_zone" "public" {
  count               = local.create_dns ? 1 : 0
  name                = var.public_dns_zone_name
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone" "private" {
  count               = local.create_dns ? 1 : 0
  name                = var.private_dns_zone_name
  resource_group_name = azurerm_resource_group.rg.name
}

data "azurerm_virtual_network" "aks_for_private_dns" {
  count               = local.create_dns && local.can_link_private_dns_vnet ? 1 : 0
  name                = var.aks_vnet_name
  resource_group_name = var.aks_vnet_resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "aks" {
  count                 = local.create_dns && local.can_link_private_dns_vnet ? 1 : 0
  name                  = "${var.cluster_name}-private-dns-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.private[0].name
  virtual_network_id    = data.azurerm_virtual_network.aks_for_private_dns[0].id
  registration_enabled  = false
}

resource "azurerm_dns_a_record" "public_records" {
  for_each            = local.create_dns ? var.public_dns_a_records : {}
  name                = each.key
  zone_name           = azurerm_dns_zone.public[0].name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 300
  records             = each.value
}

resource "azurerm_private_dns_a_record" "private_records" {
  for_each            = local.create_dns ? var.private_dns_a_records : {}
  name                = each.key
  zone_name           = azurerm_private_dns_zone.private[0].name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 300
  records             = each.value
}

