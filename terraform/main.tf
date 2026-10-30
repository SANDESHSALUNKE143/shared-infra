module "stack" {
  source = "./modules/stack"

  environment                  = var.environment
  resource_group_name          = var.resource_group_name
  operator_cidrs               = var.operator_cidrs
  alert_email                  = var.alert_email
  vm_size                      = var.vm_size
  os_disk_size_gb              = var.os_disk_size_gb
  data_disk_size_gb            = var.data_disk_size_gb
  acr_sku                      = var.acr_sku
  acr_zone_redundancy          = var.acr_zone_redundancy
  monthly_budget_usd           = var.monthly_budget_usd
  enable_night_shutdown        = var.enable_night_shutdown
  shutdown_time                = var.shutdown_time
  startup_time                 = var.startup_time
  timezone                     = var.timezone
  github_repository            = var.github_repository
  github_branch                = var.github_branch
  address_space                = var.address_space
  subnet_prefix                = var.subnet_prefix
  backup_retention_days        = var.backup_retention_days
  backup_redundancy            = var.backup_redundancy
  storage_replication          = var.storage_replication
  key_vault_soft_delete_days   = var.key_vault_soft_delete_days
  key_vault_purge_protection   = var.key_vault_purge_protection
  log_analytics_retention_days = var.log_analytics_retention_days
}
