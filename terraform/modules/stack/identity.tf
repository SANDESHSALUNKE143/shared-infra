resource "azuread_application" "github" {
  display_name     = "github-shared-infra-${var.environment}"
  sign_in_audience = "AzureADMyOrg"
  owners           = [data.azuread_client_config.current.object_id]

  lifecycle {
    ignore_changes = [owners]
  }
}

resource "azuread_service_principal" "github" {
  client_id = azuread_application.github.client_id
  owners    = [data.azuread_client_config.current.object_id]

  lifecycle {
    ignore_changes = [owners]
  }
}

resource "azuread_application_federated_identity_credential" "branch" {
  application_id = azuread_application.github.id
  display_name   = "shared-infra-${var.environment}-branch"
  description    = "GitHub Actions on ${var.github_branch} applies the ${var.environment} environment."
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_repository}:ref:refs/heads/${var.github_branch}"
}

resource "azuread_application_federated_identity_credential" "pull_request" {
  application_id = azuread_application.github.id
  display_name   = "shared-infra-${var.environment}-pull-request"
  description    = "A pull request from a collaborator plans the ${var.environment} environment."
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_repository}:pull_request"
}

# The workflow app has to read and update its own registration on the next plan.
resource "azuread_directory_role" "app_admin" {
  display_name = "Application Administrator"
}

resource "azuread_directory_role_assignment" "github" {
  # Graph stores the role template id. The directory role object id drifts on every plan.
  role_id             = azuread_directory_role.app_admin.template_id
  principal_object_id = azuread_service_principal.github.object_id
}

resource "azurerm_user_assigned_identity" "vm" {
  name                = "id-shared-infra-${var.environment}"
  location            = data.azurerm_resource_group.this.location
  resource_group_name = data.azurerm_resource_group.this.name
  tags                = local.tags
}

resource "azurerm_role_assignment" "caller_key_vault" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id

  lifecycle {
    ignore_changes = [principal_id]
  }
}

resource "azurerm_role_assignment" "github_contributor" {
  scope                            = data.azurerm_resource_group.this.id
  role_definition_name             = "Contributor"
  principal_id                     = azuread_service_principal.github.object_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "github_role_admin" {
  scope                            = data.azurerm_resource_group.this.id
  role_definition_name             = "User Access Administrator"
  principal_id                     = azuread_service_principal.github.object_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "github_key_vault" {
  scope                            = azurerm_key_vault.this.id
  role_definition_name             = "Key Vault Administrator"
  principal_id                     = azuread_service_principal.github.object_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "github_cost" {
  scope                            = data.azurerm_resource_group.this.id
  role_definition_name             = "Cost Management Contributor"
  principal_id                     = azuread_service_principal.github.object_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "github_state" {
  scope                            = data.azurerm_storage_account.state.id
  role_definition_name             = "Storage Blob Data Contributor"
  principal_id                     = azuread_service_principal.github.object_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "vm_secrets" {
  scope                            = azurerm_key_vault.this.id
  role_definition_name             = "Key Vault Secrets User"
  principal_id                     = azurerm_user_assigned_identity.vm.principal_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "vm_queue" {
  scope                            = azurerm_storage_account.logs.id
  role_definition_name             = "Storage Queue Data Contributor"
  principal_id                     = azurerm_user_assigned_identity.vm.principal_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "vm_registry" {
  scope                            = azurerm_container_registry.this.id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_user_assigned_identity.vm.principal_id
  skip_service_principal_aad_check = true
}
