resource "azurerm_key_vault" "this" {
  name                          = "kvsin${var.environment}${random_string.suffix.result}"
  location                      = data.azurerm_resource_group.this.location
  resource_group_name           = data.azurerm_resource_group.this.name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  rbac_authorization_enabled    = true
  purge_protection_enabled      = var.key_vault_purge_protection
  soft_delete_retention_days    = var.key_vault_soft_delete_days
  public_network_access_enabled = true
  tags                          = local.tags
}

resource "time_sleep" "rbac" {
  depends_on = [
    azurerm_role_assignment.caller_key_vault,
    azurerm_role_assignment.github_key_vault,
  ]

  create_duration = "60s"
}

resource "azurerm_key_vault_secret" "storage_connection" {
  name         = "storage-connection-string"
  value        = azurerm_storage_account.logs.primary_connection_string
  key_vault_id = azurerm_key_vault.this.id
  tags         = local.tags

  depends_on = [time_sleep.rbac]
}

resource "azurerm_key_vault_secret" "registry_password" {
  name         = "registry-password"
  value        = azurerm_container_registry.this.admin_password
  key_vault_id = azurerm_key_vault.this.id
  tags         = local.tags

  depends_on = [time_sleep.rbac]
}

resource "azurerm_key_vault_secret" "ssh_private_key" {
  name         = "vm-ssh-private-key"
  value        = tls_private_key.vm.private_key_openssh
  key_vault_id = azurerm_key_vault.this.id
  tags         = local.tags

  depends_on = [time_sleep.rbac]
}
