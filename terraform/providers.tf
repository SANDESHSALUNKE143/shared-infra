provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }

  resource_provider_registrations = "core"
  resource_providers_to_register = [
    "Microsoft.KeyVault",
    "Microsoft.ContainerRegistry",
    "Microsoft.RecoveryServices",
    "Microsoft.OperationalInsights",
    "Microsoft.Insights",
    "Microsoft.Logic",
    "Microsoft.DevTestLab",
    "Microsoft.Consumption",
    "Microsoft.ManagedIdentity",
  ]
}

provider "azuread" {}

provider "github" {
  owner = split("/", var.github_repository)[0]
}
