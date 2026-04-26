resource "random_string" "logs_sa_suffix" {
  count   = var.enable_logs_storage && var.logs_storage_account_name == "" ? 1 : 0
  length  = 8
  upper   = false
  lower   = true
  numeric = true
  special = false
}

locals {
  logs_storage_account_name_effective = var.logs_storage_account_name != "" ? var.logs_storage_account_name : "gglogs${random_string.logs_sa_suffix[0].result}"
}

resource "azurerm_storage_account" "logs" {
  count                    = var.enable_logs_storage ? 1 : 0
  name                     = local.logs_storage_account_name_effective
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
}

resource "azurerm_storage_container" "logs" {
  count                 = var.enable_logs_storage ? 1 : 0
  name                  = var.logs_container_name
  storage_account_name  = azurerm_storage_account.logs[0].name
  container_access_type = "private"
}

resource "azurerm_storage_management_policy" "logs" {
  count              = var.enable_logs_storage ? 1 : 0
  storage_account_id = azurerm_storage_account.logs[0].id

  rule {
    name    = "logs-retention"
    enabled = true

    filters {
      blob_types   = ["blockBlob"]
      prefix_match = ["${var.logs_container_name}/"]
    }

    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = var.logs_retention_days
      }
      snapshot {
        delete_after_days_since_creation_greater_than = var.logs_retention_days
      }
      version {
        delete_after_days_since_creation = var.logs_retention_days
      }
    }
  }
}

