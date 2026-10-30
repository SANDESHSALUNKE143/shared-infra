resource "github_repository_environment" "this" {
  count       = var.manage_github_environment ? 1 : 0
  repository  = local.github_name
  environment = var.environment
}

resource "github_actions_environment_secret" "storage_connection" {
  count           = var.manage_github_environment ? 1 : 0
  repository      = local.github_name
  environment     = github_repository_environment.this[0].environment
  secret_name     = "AZURE_STORAGE_CONNECTION_STRING"
  plaintext_value = azurerm_storage_account.logs.primary_connection_string
}

resource "github_actions_environment_secret" "registry_username" {
  count           = var.manage_github_environment ? 1 : 0
  repository      = local.github_name
  environment     = github_repository_environment.this[0].environment
  secret_name     = "REGISTRY_USERNAME"
  plaintext_value = azurerm_container_registry.this.admin_username
}

resource "github_actions_environment_secret" "registry_password" {
  count           = var.manage_github_environment ? 1 : 0
  repository      = local.github_name
  environment     = github_repository_environment.this[0].environment
  secret_name     = "REGISTRY_PASSWORD"
  plaintext_value = azurerm_container_registry.this.admin_password
}

resource "github_actions_environment_secret" "ssh_private_key" {
  count           = var.manage_github_environment ? 1 : 0
  repository      = local.github_name
  environment     = github_repository_environment.this[0].environment
  secret_name     = "VM_SSH_PRIVATE_KEY"
  plaintext_value = tls_private_key.vm.private_key_openssh
}
