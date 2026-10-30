resource "azurerm_log_analytics_workspace" "this" {
  name                = "log-shared-infra-${var.environment}"
  location            = data.azurerm_resource_group.this.location
  resource_group_name = data.azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_analytics_retention_days
  tags                = local.tags
}

resource "azurerm_monitor_action_group" "ops" {
  name                = "ag-shared-infra-${var.environment}"
  resource_group_name = data.azurerm_resource_group.this.name
  short_name          = "inf${var.environment}"
  tags                = local.tags

  email_receiver {
    name                    = "ops"
    email_address           = var.alert_email
    use_common_alert_schema = true
  }
}

resource "azurerm_monitor_metric_alert" "vm_availability" {
  name                = "vm-availability-${var.environment}"
  resource_group_name = data.azurerm_resource_group.this.name
  scopes              = [azurerm_linux_virtual_machine.this.id]
  description         = "The virtual machine availability metric is below 1."
  severity            = 1
  frequency           = "PT1M"
  window_size         = "PT5M"
  tags                = local.tags

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "VmAvailabilityMetric"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 1
  }

  action {
    action_group_id = azurerm_monitor_action_group.ops.id
  }
}

resource "azurerm_monitor_metric_alert" "storage_availability" {
  name                = "storage-availability-${var.environment}"
  resource_group_name = data.azurerm_resource_group.this.name
  scopes              = [azurerm_storage_account.logs.id]
  description         = "The log storage account availability is below 99 percent."
  severity            = 1
  frequency           = "PT1M"
  window_size         = "PT5M"
  tags                = local.tags

  criteria {
    metric_namespace = "Microsoft.Storage/storageAccounts"
    metric_name      = "Availability"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 99
  }

  action {
    action_group_id = azurerm_monitor_action_group.ops.id
  }
}

resource "azurerm_monitor_metric_alert" "storage_errors" {
  name                = "storage-errors-${var.environment}"
  resource_group_name = data.azurerm_resource_group.this.name
  scopes              = [azurerm_storage_account.logs.id]
  description         = "The log storage account is returning server errors."
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT5M"
  tags                = local.tags

  criteria {
    metric_namespace = "Microsoft.Storage/storageAccounts"
    metric_name      = "Transactions"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = var.storage_error_threshold

    dimension {
      name     = "ResponseType"
      operator = "Include"
      values   = ["ServerOtherError", "ServerTimeoutError", "ServerBusyError"]
    }
  }

  action {
    action_group_id = azurerm_monitor_action_group.ops.id
  }
}

resource "azurerm_monitor_data_collection_rule" "vm" {
  name                = "dcr-shared-infra-${var.environment}"
  location            = data.azurerm_resource_group.this.location
  resource_group_name = data.azurerm_resource_group.this.name
  kind                = "Linux"
  tags                = local.tags

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.this.id
      name                  = "la"
    }
  }

  data_flow {
    streams      = ["Microsoft-Syslog"]
    destinations = ["la"]
  }

  data_sources {
    syslog {
      name           = "syslog"
      streams        = ["Microsoft-Syslog"]
      facility_names = ["auth", "authpriv", "daemon", "syslog"]
      log_levels     = ["Info", "Notice", "Warning", "Error", "Critical", "Alert", "Emergency"]
    }
  }
}

resource "azurerm_monitor_data_collection_rule_association" "vm" {
  name                    = "dcr-shared-infra-${var.environment}"
  target_resource_id      = azurerm_linux_virtual_machine.this.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.vm.id

  depends_on = [azurerm_virtual_machine_extension.monitor]
}

locals {
  diagnostic_targets = merge(
    {
      key_vault = azurerm_key_vault.this.id
      registry  = azurerm_container_registry.this.id
    },
    var.enable_night_shutdown ? {
      logic_app = azurerm_logic_app_workflow.start[0].id
    } : {}
  )
}

# Network security groups reject AllMetrics unless metric export is enabled
# on the subscription. Their event and rule-counter logs still ship.
resource "azurerm_monitor_diagnostic_setting" "nsg" {
  name                       = "diag-nsg"
  target_resource_id         = azurerm_network_security_group.this.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  enabled_log {
    category_group = "allLogs"
  }
}

resource "azurerm_monitor_diagnostic_setting" "logs" {
  for_each = local.diagnostic_targets

  name                       = "diag-${each.key}"
  target_resource_id         = each.value
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "vault" {
  name                       = "diag-vault"
  target_resource_id         = azurerm_recovery_services_vault.this.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  enabled_log {
    category_group = "allLogs"
  }
}

resource "azurerm_monitor_diagnostic_setting" "public_ip" {
  name                       = "diag-public-ip"
  target_resource_id         = azurerm_public_ip.this.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "vm" {
  name                       = "diag-vm"
  target_resource_id         = azurerm_linux_virtual_machine.this.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "storage" {
  name                       = "diag-storage"
  target_resource_id         = azurerm_storage_account.logs.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  enabled_metric {
    category = "Transaction"
  }
}

resource "azurerm_monitor_diagnostic_setting" "queue" {
  name                       = "diag-queue"
  target_resource_id         = "${azurerm_storage_account.logs.id}/queueServices/default"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }

  enabled_metric {
    category = "Transaction"
  }
}
