resource "random_password" "postgres_dev_admin_password" {
  count            = var.enable_managed_postgres ? 1 : 0
  length           = 24
  special          = true
  override_special = "!@#%^*-_=+"
}

resource "random_password" "postgres_prod_admin_password" {
  count            = var.enable_managed_postgres ? 1 : 0
  length           = 24
  special          = true
  override_special = "!@#%^*-_=+"
}

resource "azurerm_postgresql_flexible_server" "dev" {
  count               = var.enable_managed_postgres ? 1 : 0
  name                = "${var.cluster_name}-pg-dev"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.postgres_location

  version                   = var.postgres_version
  administrator_login       = var.postgres_admin_username
  administrator_password    = random_password.postgres_dev_admin_password[0].result
  sku_name                  = var.postgres_dev_sku_name
  storage_mb                = var.postgres_dev_storage_mb
  backup_retention_days     = var.postgres_dev_backup_retention_days
  geo_redundant_backup_enabled = false

  public_network_access_enabled = var.postgres_public_network_access_enabled

  lifecycle {
    ignore_changes = [zone]
  }
}

resource "azurerm_postgresql_flexible_server_database" "dev" {
  count     = var.enable_managed_postgres ? 1 : 0
  name      = var.postgres_dev_db_name
  server_id = azurerm_postgresql_flexible_server.dev[0].id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "dev_allow_azure" {
  count             = var.enable_managed_postgres && var.postgres_public_network_access_enabled ? 1 : 0
  name              = "allow-azure-services"
  server_id         = azurerm_postgresql_flexible_server.dev[0].id
  start_ip_address  = "0.0.0.0"
  end_ip_address    = "0.0.0.0"
}

resource "azurerm_postgresql_flexible_server" "prod" {
  count               = var.enable_managed_postgres ? 1 : 0
  name                = "${var.cluster_name}-pg-prod"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.postgres_location

  version                   = var.postgres_version
  administrator_login       = var.postgres_admin_username
  administrator_password    = random_password.postgres_prod_admin_password[0].result
  sku_name                  = var.postgres_prod_sku_name
  storage_mb                = var.postgres_prod_storage_mb
  backup_retention_days     = var.postgres_prod_backup_retention_days
  geo_redundant_backup_enabled = var.postgres_prod_geo_redundant_backup_enabled

  public_network_access_enabled = var.postgres_public_network_access_enabled

  high_availability {
    mode = var.postgres_prod_ha_mode
  }

  lifecycle {
    ignore_changes = [zone]
  }
}

resource "azurerm_postgresql_flexible_server_database" "prod" {
  count     = var.enable_managed_postgres ? 1 : 0
  name      = var.postgres_prod_db_name
  server_id = azurerm_postgresql_flexible_server.prod[0].id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "prod_allow_azure" {
  count             = var.enable_managed_postgres && var.postgres_public_network_access_enabled ? 1 : 0
  name              = "allow-azure-services"
  server_id         = azurerm_postgresql_flexible_server.prod[0].id
  start_ip_address  = "0.0.0.0"
  end_ip_address    = "0.0.0.0"
}

