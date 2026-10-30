output "public_ip" {
  description = "Public IP operators use as PUBLIC_HOST."
  value       = azurerm_public_ip.this.ip_address
}

output "ssh_command" {
  description = "SSH command for the virtual machine."
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.this.ip_address}"
}

output "vm_name" {
  description = "Virtual machine name."
  value       = azurerm_linux_virtual_machine.this.name
}

output "key_vault_name" {
  description = "Key Vault name."
  value       = azurerm_key_vault.this.name
}

output "storage_account_name" {
  description = "Log storage account name."
  value       = azurerm_storage_account.logs.name
}

output "acr_login_server" {
  description = "Container registry login server."
  value       = azurerm_container_registry.this.login_server
}

output "github_client_id" {
  description = "Client id of the GitHub Actions app registration."
  value       = azuread_application.github.client_id
}
