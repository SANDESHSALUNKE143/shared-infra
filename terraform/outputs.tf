output "public_ip" {
  description = "Public IP operators use as PUBLIC_HOST."
  value       = module.stack.public_ip
}

output "ssh_command" {
  description = "SSH command. The private key is in Key Vault and in the GitHub environment secret VM_SSH_PRIVATE_KEY."
  value       = module.stack.ssh_command
}

output "vm_name" {
  description = "Virtual machine name."
  value       = module.stack.vm_name
}

output "key_vault_name" {
  description = "Key Vault that holds the storage connection string, the registry password, and the SSH key."
  value       = module.stack.key_vault_name
}

output "storage_account_name" {
  description = "Storage account that holds the app-logs queue."
  value       = module.stack.storage_account_name
}

output "acr_login_server" {
  description = "Container registry login server."
  value       = module.stack.acr_login_server
}

output "github_client_id" {
  description = "Client id of the app registration this stack created. After the first apply, put this in the AZURE_CLIENT_ID_<ENV> repository variable."
  value       = module.stack.github_client_id
}
