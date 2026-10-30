terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.20"
    }
  }

  backend "azurerm" {
    container_name   = "tfstate"
    key              = "bootstrap.tfstate"
    use_azuread_auth = true
  }
}
