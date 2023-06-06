resource "azurerm_network_interface" "nic_config" {
  count                           = var.node_count_var  
  name                            = "${var.node_host_names_var[count.index]}-nic" 
  location                        = var.location_var
  resource_group_name             = var.resource_group_var
  enable_accelerated_networking   = true

  ip_configuration {
    name                          = var.node_host_names_var[count.index]
    subnet_id                     = data.azurerm_subnet.subnet_config.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.node_ips_var[count.index]
  }
  depends_on = [data.azurerm_virtual_network.vnet_config]

  
}

resource "azurerm_windows_virtual_machine" "vm_config" {
  count                           = var.node_count_var 
  name                            = var.node_host_names_var[count.index]
  resource_group_name             = var.resource_group_var
  location                        = var.location_var
  size                            = var.vm_size_var
  admin_username                  = var.admin_username_var
  admin_password                  = var.admin_password_var
  network_interface_ids           = [azurerm_network_interface.nic_config[count.index].id]
  provision_vm_agent              = "true"
  

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = var.storage_account_type_var
    disk_size_gb         = var.os_disk_size_gb_var
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = var.os_offer_var
    sku       = var.sku_var
    version   = "latest"
  }

  winrm_listener {
    protocol  = "Http"
  }
  ## Added lately from https://stackoverflow.com/questions/69390742/terraform-windows-server-2016-adding-and-running-scripts-using-winery
  additional_unattend_content {
      setting      = "AutoLogon"
      content      = "<AutoLogon><Password><Value>${var.admin_password_var}</Value></Password><Enabled>true</Enabled><LogonCount>1</LogonCount><Username>${var.admin_username_var}</Username></AutoLogon>"
  }
  additional_unattend_content {
      setting      = "FirstLogonCommands"
      content      = "${file("./FirstLogincommand.xml")}"
  }

  custom_data = "${filebase64("./winrm.ps1")}"

  depends_on = [azurerm_network_interface.nic_config]
  
}

resource "azurerm_managed_disk" "data-disk" {
    count                        = "${var.is_data_disk_enable == true ? 1 : 0}" * var.node_count_var
    name                         = "${var.node_host_names_var[count.index]}-datadisk"
    location                     = var.location_var
    resource_group_name          = var.resource_group_var
    create_option                = "Empty"
    storage_account_type         = var.storage_account_type_var
    disk_size_gb                 = var.data_disk_size_gb_var
}

resource "azurerm_virtual_machine_data_disk_attachment" "vm-node-data-disk" {
    count                     = "${var.is_data_disk_enable == true ? 1 : 0}" * var.node_count_var
    managed_disk_id           = azurerm_managed_disk.data-disk[count.index].id
    virtual_machine_id        = azurerm_windows_virtual_machine.vm_config[count.index].id
    caching                   = "ReadWrite"
    write_accelerator_enabled = false
    lun                       = count.index

   depends_on = [azurerm_managed_disk.data-disk]
}
