resource "azurerm_container_registry" "this" {
  name                          = "acrsin${var.environment}${random_string.suffix.result}"
  resource_group_name           = data.azurerm_resource_group.this.name
  location                      = data.azurerm_resource_group.this.location
  sku                           = var.acr_sku
  admin_enabled                 = true
  public_network_access_enabled = true
  zone_redundancy_enabled       = var.acr_zone_redundancy ? true : null
  anonymous_pull_enabled        = false
  retention_policy_in_days      = var.acr_sku == "Premium" ? 14 : null
  tags                          = local.tags
}
