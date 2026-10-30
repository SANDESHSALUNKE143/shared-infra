locals {
  tags = {
    project     = "shared-infra"
    environment = var.environment
    managed_by  = "terraform"
  }

  github_name = split("/", var.github_repository)[1]

  # Keep this in step with terraform/init.sh. The name is the state account in this resource group.
  state_storage_account_name = "sttf${var.environment}${substr(md5(data.azurerm_client_config.current.subscription_id), 0, 10)}"

  startup_hour   = tonumber(split(":", var.startup_time)[0])
  startup_minute = tonumber(split(":", var.startup_time)[1])

  ui_ports = ["3000", "5601", "3003", "5678", "5000", "7474", "7687", "6333"]
}
