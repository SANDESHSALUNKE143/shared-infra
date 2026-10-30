variable "environment" {
  type        = string
  description = "dev, uat, or prod. Production is prod."

  validation {
    condition     = contains(["dev", "uat", "prod"], var.environment)
    error_message = "environment must be dev, uat, or prod."
  }
}

variable "resource_group_name" {
  type        = string
  description = "Name of the empty resource group that already exists for this environment."
}

variable "operator_cidrs" {
  type        = list(string)
  description = "Addresses allowed to open SSH and the web UIs. Use your own public address."

  validation {
    condition = length(var.operator_cidrs) > 0 && alltrue([
      for cidr in var.operator_cidrs : cidr != "0.0.0.0/0" && cidr != "::/0"
    ])
    error_message = "operator_cidrs must list your address. Opening the virtual machine to the whole internet is refused."
  }
}

variable "alert_email" {
  type        = string
  description = "Address that receives metric alerts and budget warnings."
}

variable "vm_size" {
  type        = string
  description = "Virtual machine size. Dev is the smallest, UAT is in between, and prod is the full size."
}

variable "os_disk_size_gb" {
  type        = number
  description = "Operating system disk size in GiB."

  validation {
    condition     = var.os_disk_size_gb >= 64
    error_message = "os_disk_size_gb must be at least 64."
  }
}

variable "data_disk_size_gb" {
  type        = number
  description = "Data disk size in GiB. Docker volumes live on this disk."

  validation {
    condition     = var.data_disk_size_gb >= 256
    error_message = "data_disk_size_gb must be at least 256."
  }
}

variable "acr_sku" {
  type        = string
  description = "Container registry SKU: Basic, Standard, or Premium."

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.acr_sku)
    error_message = "acr_sku must be Basic, Standard, or Premium."
  }
}

variable "acr_zone_redundancy" {
  type        = bool
  description = "Zone-redundant registry. Requires the Premium SKU and a region with availability zones."

  validation {
    condition     = !var.acr_zone_redundancy || var.acr_sku == "Premium"
    error_message = "acr_zone_redundancy requires acr_sku Premium."
  }
}

variable "monthly_budget_usd" {
  type        = number
  description = "Monthly budget for this environment, in USD. Dev and UAT are lower than prod."

  validation {
    condition     = var.monthly_budget_usd > 0
    error_message = "monthly_budget_usd must be greater than zero."
  }
}

variable "enable_night_shutdown" {
  type        = bool
  description = "Stop the virtual machine overnight and start it in the morning. Production leaves this off."
}

variable "shutdown_time" {
  type        = string
  description = "Daily stop time as HHmm in timezone. Dev and UAT default to 2000."
  default     = "2000"

  validation {
    condition     = can(regex("^([01][0-9]|2[0-3])[0-5][0-9]$", var.shutdown_time))
    error_message = "shutdown_time is HHmm, for example 2000."
  }
}

variable "startup_time" {
  type        = string
  description = "Daily start time as HH:MM in timezone. Dev and UAT default to 08:00."
  default     = "08:00"

  validation {
    condition     = can(regex("^([01][0-9]|2[0-3]):[0-5][0-9]$", var.startup_time))
    error_message = "startup_time is HH:MM, for example 08:00."
  }
}

variable "timezone" {
  type        = string
  description = "Windows time zone id used by the night schedule and the backup policy. UTC is the default."
  default     = "UTC"
}

variable "github_repository" {
  type        = string
  description = "GitHub repository that applies this stack, as owner/name."

  validation {
    condition     = length(split("/", var.github_repository)) == 2
    error_message = "github_repository is owner/name."
  }
}

variable "github_branch" {
  type        = string
  description = "Branch whose merge applies this environment. dev, uat, or main."
}

variable "address_space" {
  type        = list(string)
  description = "Virtual network address space. Each environment uses its own range."
}

variable "subnet_prefix" {
  type        = string
  description = "Subnet prefix inside address_space."

  validation {
    condition     = can(cidrhost(var.subnet_prefix, 0))
    error_message = "subnet_prefix must be a CIDR block."
  }
}

variable "backup_retention_days" {
  type        = number
  description = "How many daily virtual machine backups to keep."

  validation {
    condition     = var.backup_retention_days >= 7
    error_message = "backup_retention_days must be at least 7."
  }
}

variable "backup_redundancy" {
  type        = string
  description = "Recovery vault storage. Production uses GeoRedundant."

  validation {
    condition     = contains(["LocallyRedundant", "ZoneRedundant", "GeoRedundant"], var.backup_redundancy)
    error_message = "backup_redundancy must be LocallyRedundant, ZoneRedundant, or GeoRedundant."
  }
}

variable "storage_replication" {
  type        = string
  description = "Replication for the log storage account. Production uses GRS."

  validation {
    condition     = contains(["LRS", "ZRS", "GRS", "RAGRS"], var.storage_replication)
    error_message = "storage_replication must be LRS, ZRS, GRS, or RAGRS."
  }
}

variable "key_vault_soft_delete_days" {
  type        = number
  description = "Key Vault soft-delete retention. Production uses 90."

  validation {
    condition     = var.key_vault_soft_delete_days >= 7 && var.key_vault_soft_delete_days <= 90
    error_message = "key_vault_soft_delete_days must be from 7 to 90."
  }
}

variable "key_vault_purge_protection" {
  type        = bool
  description = "Key Vault purge protection. Production turns this on. It cannot be turned off later."

  validation {
    condition     = var.environment != "prod" || var.key_vault_purge_protection
    error_message = "Production Key Vault keeps purge protection on."
  }
}

variable "log_analytics_retention_days" {
  type        = number
  description = "Log Analytics retention in days."

  validation {
    condition     = var.log_analytics_retention_days >= 30
    error_message = "log_analytics_retention_days must be at least 30."
  }
}
