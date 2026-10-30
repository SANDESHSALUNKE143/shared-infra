resource "azurerm_dev_test_global_vm_shutdown_schedule" "night" {
  count = var.enable_night_shutdown ? 1 : 0

  virtual_machine_id    = azurerm_linux_virtual_machine.this.id
  location              = data.azurerm_resource_group.this.location
  enabled               = true
  daily_recurrence_time = var.shutdown_time
  timezone              = var.timezone

  notification_settings {
    enabled = false
  }

  tags = local.tags
}

resource "azurerm_logic_app_workflow" "start" {
  count = var.enable_night_shutdown ? 1 : 0

  name                = "logic-start-vm-${var.environment}"
  location            = data.azurerm_resource_group.this.location
  resource_group_name = data.azurerm_resource_group.this.name
  tags                = local.tags

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "start_vm" {
  count = var.enable_night_shutdown ? 1 : 0

  scope                            = azurerm_linux_virtual_machine.this.id
  role_definition_name             = "Virtual Machine Contributor"
  principal_id                     = azurerm_logic_app_workflow.start[0].identity[0].principal_id
  skip_service_principal_aad_check = true
}

resource "azurerm_logic_app_trigger_recurrence" "start" {
  count = var.enable_night_shutdown ? 1 : 0

  name         = "weekday-morning"
  logic_app_id = azurerm_logic_app_workflow.start[0].id
  frequency    = "Day"
  interval     = 1
  time_zone    = var.timezone

  schedule {
    at_these_hours   = [local.startup_hour]
    at_these_minutes = [local.startup_minute]
  }
}

resource "azurerm_logic_app_action_custom" "start" {
  count = var.enable_night_shutdown ? 1 : 0

  name         = "start-vm"
  logic_app_id = azurerm_logic_app_workflow.start[0].id

  body = jsonencode({
    type = "Http"
    inputs = {
      method = "POST"
      uri    = "https://management.azure.com${azurerm_linux_virtual_machine.this.id}/start?api-version=2024-07-01"
      authentication = {
        type     = "ManagedServiceIdentity"
        audience = "https://management.azure.com"
      }
    }
    runAfter = {}
  })

  depends_on = [azurerm_logic_app_trigger_recurrence.start]
}
