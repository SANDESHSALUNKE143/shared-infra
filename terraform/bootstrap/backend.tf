terraform {
  backend "azurerm" {
    container_name   = "tfstate"
    key              = "bootstrap.tfstate"
    use_azuread_auth = true
  }
}
