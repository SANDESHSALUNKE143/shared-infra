variable "environment" {
  type        = string
  description = "dev, uat, or prod."
}

variable "resource_group_name" {
  type        = string
  description = "Name of the empty resource group that already exists for this environment."
}

variable "operator_cidrs" {
  type        = list(string)
  description = "Addresses allowed to open SSH and the web UIs."
}

variable "alert_email" {
  type        = string
  description = "Address that receives metric alerts and budget warnings."
}

variable "vm_size" {
  type        = string
  description = "Virtual machine size for this environment."
}

variable "os_disk_size_gb" {
  type        = number
  description = "Operating system disk size in GiB."
}

variable "data_disk_size_gb" {
  type        = number
  description = "Data disk size in GiB. Docker volumes live on this disk."
}

variable "acr_sku" {
  type        = string
  description = "Container registry SKU."
}

variable "acr_zone_redundancy" {
  type        = bool
  description = "Zone-redundant registry. Premium SKU only."
}

variable "monthly_budget_usd" {
  type        = number
  description = "Monthly budget for this environment, in USD."
}

variable "enable_night_shutdown" {
  type        = bool
  description = "Stop the virtual machine overnight and start it in the morning."
}

variable "shutdown_time" {
  type        = string
  description = "Daily stop time as HHmm in timezone."
}

variable "startup_time" {
  type        = string
  description = "Daily start time as HH:MM in timezone."
}

variable "timezone" {
  type        = string
  description = "Windows time zone id for the night schedule and the backup policy."
}

variable "github_repository" {
  type        = string
  description = "GitHub repository that applies this stack, as owner/name."
}

variable "github_branch" {
  type        = string
  description = "Branch whose merge applies this environment."
}

variable "manage_github_environment" {
  type        = bool
  description = "Create the GitHub environment and copy Key Vault secrets into it."
  default     = false
}

variable "address_space" {
  type        = list(string)
  description = "Virtual network address space."
}

variable "subnet_prefix" {
  type        = string
  description = "Subnet prefix inside address_space."
}

variable "backup_retention_days" {
  type        = number
  description = "How many daily virtual machine backups to keep."
}

variable "backup_redundancy" {
  type        = string
  description = "Recovery vault storage redundancy."
}

variable "storage_replication" {
  type        = string
  description = "Replication for the log storage account."
}

variable "key_vault_soft_delete_days" {
  type        = number
  description = "Key Vault soft-delete retention in days."
}

variable "key_vault_purge_protection" {
  type        = bool
  description = "Key Vault purge protection."
}

variable "log_analytics_retention_days" {
  type        = number
  description = "Log Analytics retention in days."
}

variable "admin_username" {
  type        = string
  description = "Linux account on the virtual machine."
  default     = "azureuser"
}

variable "storage_error_threshold" {
  type        = number
  description = "Storage server-error count in five minutes that pages the action group."
  default     = 20
}
