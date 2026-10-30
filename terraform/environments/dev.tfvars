environment         = "dev"
resource_group_name = "rg-shared-infra-dev"
# Replace this documentation address with the operator public IP before the first apply.
operator_cidrs = ["203.0.113.10/32"]
# Replace this with the address that should receive alerts and budget mail.
alert_email                  = "ops@example.com"
vm_size                      = "Standard_E4s_v3"
os_disk_size_gb              = 64
data_disk_size_gb            = 256
acr_sku                      = "Basic"
acr_zone_redundancy          = false
monthly_budget_usd           = 200
enable_night_shutdown        = true
shutdown_time                = "2000"
startup_time                 = "08:00"
timezone                     = "UTC"
github_repository            = "SANDESHSALUNKE143/shared-infra"
github_branch                = "dev"
address_space                = ["10.10.0.0/16"]
subnet_prefix                = "10.10.1.0/24"
backup_retention_days        = 7
backup_redundancy            = "LocallyRedundant"
storage_replication          = "LRS"
key_vault_soft_delete_days   = 7
key_vault_purge_protection   = false
log_analytics_retention_days = 30
