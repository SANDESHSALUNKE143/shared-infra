output "storage_account_name" {
  description = "State storage account."
  value       = azurerm_storage_account.state.name
}
