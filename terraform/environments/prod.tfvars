environment         = "prod"
resource_group_name = "rg-shared-infra-prod"
# Replace this documentation address with the operator public IP before the first apply.
operator_cidrs = ["203.0.113.10/32"]
# Replace this with the address that should receive alerts and budget mail.
alert_email                  = "ops@example.com"
vm_size                      = "Standard_E8s_v5"
os_disk_size_gb              = 64
data_disk_size_gb            = 1024
acr_sku                      = "Premium"
acr_zone_redundancy          = true
monthly_budget_usd           = 800
enable_night_shutdown        = false
shutdown_time                = "2000"
startup_time                 = "08:00"
timezone                     = "UTC"
github_repository            = "SANDESHSALUNKE143/shared-infra"
github_branch                = "main"
address_space                = ["10.30.0.0/16"]
subnet_prefix                = "10.30.1.0/24"
backup_retention_days        = 30
backup_redundancy            = "GeoRedundant"
storage_replication          = "GRS"
key_vault_soft_delete_days   = 90
key_vault_purge_protection   = true
log_analytics_retention_days = 90
