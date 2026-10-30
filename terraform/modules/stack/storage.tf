resource "azurerm_storage_account" "logs" {
  name                              = "stsin${var.environment}${random_string.suffix.result}"
  resource_group_name               = data.azurerm_resource_group.this.name
  location                          = data.azurerm_resource_group.this.location
  account_tier                      = "Standard"
  account_replication_type          = var.storage_replication
  account_kind                      = "StorageV2"
  min_tls_version                   = "TLS1_2"
  https_traffic_only_enabled        = true
  shared_access_key_enabled         = true
  allow_nested_items_to_be_public   = false
  public_network_access_enabled     = true
  infrastructure_encryption_enabled = true
  tags                              = local.tags

  blob_properties {
    delete_retention_policy {
      days = var.environment == "prod" ? 30 : 7
    }
  }
}

resource "azurerm_storage_queue" "logs" {
  name               = "app-logs"
  storage_account_id = azurerm_storage_account.logs.id
}

resource "azurerm_storage_queue" "poison" {
  name               = "app-logs-poison"
  storage_account_id = azurerm_storage_account.logs.id
}

data "azurerm_storage_account" "state" {
  name                = local.state_storage_account_name
  resource_group_name = data.azurerm_resource_group.this.name
}
