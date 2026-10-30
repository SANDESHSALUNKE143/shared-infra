resource "tls_private_key" "vm" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

locals {
  cloud_init = "#cloud-config\n${yamlencode({
    write_files = [
      {
        path        = "/usr/local/sbin/shared-infra-boot.sh"
        permissions = "0755"
        content = templatefile("${path.module}/boot.sh.tpl", {
          environment        = var.environment
          key_vault_name     = azurerm_key_vault.this.name
          identity_client_id = azurerm_user_assigned_identity.vm.client_id
          admin_username     = var.admin_username
          github_repository  = var.github_repository
          github_branch      = var.github_branch
          public_ip          = azurerm_public_ip.this.ip_address
        })
      },
      {
        path        = "/etc/systemd/system/shared-infra-boot.service"
        permissions = "0644"
        content     = file("${path.module}/boot.service")
      },
    ]
    runcmd = [
      "systemctl daemon-reload",
      "systemctl enable shared-infra-boot.service",
      "systemctl start --no-block shared-infra-boot.service",
    ]
  })}"
}

resource "azurerm_linux_virtual_machine" "this" {
  name                            = "vm-infra-${var.environment}"
  location                        = data.azurerm_resource_group.this.location
  resource_group_name             = data.azurerm_resource_group.this.name
  size                            = var.vm_size
  admin_username                  = var.admin_username
  network_interface_ids           = [azurerm_network_interface.this.id]
  disable_password_authentication = true
  custom_data                     = base64encode(local.cloud_init)
  tags                            = local.tags

  # The secret and the reader role exist before the guest reads Key Vault.
  depends_on = [
    azurerm_key_vault_secret.storage_connection,
    azurerm_role_assignment.vm_secrets,
  ]

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.vm.id]
  }

  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.vm.public_key_openssh
  }

  os_disk {
    name                 = "osdisk-infra-${var.environment}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = var.os_disk_size_gb
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.logs.primary_blob_endpoint
  }
}

resource "azurerm_managed_disk" "data" {
  name                 = "disk-infra-${var.environment}"
  location             = data.azurerm_resource_group.this.location
  resource_group_name  = data.azurerm_resource_group.this.name
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = var.data_disk_size_gb
  tags                 = local.tags
}

resource "azurerm_virtual_machine_data_disk_attachment" "data" {
  managed_disk_id    = azurerm_managed_disk.data.id
  virtual_machine_id = azurerm_linux_virtual_machine.this.id
  lun                = 0
  caching            = "ReadWrite"
}

resource "azurerm_virtual_machine_extension" "monitor" {
  name                       = "AzureMonitorLinuxAgent"
  virtual_machine_id         = azurerm_linux_virtual_machine.this.id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
  tags                       = local.tags
}
