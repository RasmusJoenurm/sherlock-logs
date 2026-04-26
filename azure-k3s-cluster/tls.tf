data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "tls" {
  count                       = var.enable_tls_certificates ? 1 : 0
  name                        = var.key_vault_name
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  enable_rbac_authorization   = true
}

resource "azurerm_role_assignment" "tls_current_user_admin" {
  count                = var.enable_tls_certificates ? 1 : 0
  scope                = azurerm_key_vault.tls[0].id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_key_vault_certificate" "public_tls" {
  count        = var.enable_tls_certificates ? 1 : 0
  name         = "public-edge-tls"
  key_vault_id = azurerm_key_vault.tls[0].id

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }

    key_properties {
      exportable = true
      key_size   = 2048
      key_type   = "RSA"
      reuse_key  = true
    }

    secret_properties {
      content_type = "application/x-pkcs12"
    }

    x509_certificate_properties {
      subject            = "CN=${var.public_tls_common_name}"
      validity_in_months = 12
      key_usage = [
        "digitalSignature",
        "keyEncipherment"
      ]

      subject_alternative_names {
        dns_names = [var.public_tls_common_name]
      }
    }

    lifetime_action {
      action {
        action_type = "AutoRenew"
      }

      trigger {
        days_before_expiry = 30
      }
    }
  }

  depends_on = [azurerm_role_assignment.tls_current_user_admin]
}

resource "azurerm_key_vault_certificate" "private_tls" {
  count        = var.enable_tls_certificates ? 1 : 0
  name         = "private-edge-tls"
  key_vault_id = azurerm_key_vault.tls[0].id

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }

    key_properties {
      exportable = true
      key_size   = 2048
      key_type   = "RSA"
      reuse_key  = true
    }

    secret_properties {
      content_type = "application/x-pkcs12"
    }

    x509_certificate_properties {
      subject            = "CN=${var.private_tls_common_name}"
      validity_in_months = 12
      key_usage = [
        "digitalSignature",
        "keyEncipherment"
      ]

      subject_alternative_names {
        dns_names = [var.private_tls_common_name]
      }
    }

    lifetime_action {
      action {
        action_type = "AutoRenew"
      }

      trigger {
        days_before_expiry = 30
      }
    }
  }

  depends_on = [azurerm_role_assignment.tls_current_user_admin]
}

