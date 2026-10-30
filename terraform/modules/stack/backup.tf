resource "azurerm_recovery_services_vault" "this" {
  name                = "rsv-shared-infra-${var.environment}"
  location            = data.azurerm_resource_group.this.location
  resource_group_name = data.azurerm_resource_group.this.name
  sku                 = "Standard"
  storage_mode_type   = var.backup_redundancy
  tags                = local.tags
}

resource "azurerm_backup_policy_vm" "daily" {
  name                = "daily-vm-${var.environment}"
  resource_group_name = data.azurerm_resource_group.this.name
  recovery_vault_name = azurerm_recovery_services_vault.this.name
  timezone            = var.timezone

  backup {
    frequency = "Daily"
    time      = "02:00"
  }

  retention_daily {
    count = var.backup_retention_days
  }
}

resource "azurerm_backup_protected_vm" "this" {
  resource_group_name = data.azurerm_resource_group.this.name
  recovery_vault_name = azurerm_recovery_services_vault.this.name
  source_vm_id        = azurerm_linux_virtual_machine.this.id
  backup_policy_id    = azurerm_backup_policy_vm.daily.id
}
