variable "environment" {
  type        = string
  description = "dev, uat, or prod."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group that already exists for this environment."
}

variable "storage_account_name" {
  type        = string
  description = "Globally unique name for the Terraform state account. terraform/init.sh computes it."
}

variable "account_replication_type" {
  type        = string
  description = "LRS for dev and UAT. GRS for production."
  default     = "LRS"
}
