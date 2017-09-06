variable "subscription_id" {}
variable "client_id" {}
variable "client_secret" {}
variable "tenant_id" {}


provider "azurerm" {
  subscription_id = "${var.subscription_id}"
  client_id       = "${var.client_id}"
  client_secret   = "${var.client_secret}"
  tenant_id       = "${var.tenant_id}"
}


resource "azurerm_resource_group" "storage" {
  name = "certs"
  location = "westus2"
}

resource "azurerm_virtual_network" "learning" {
  name                = "storage_network"
  address_space       = ["10.0.0.0/16"]
  location            = "${azurerm_resource_group.storage.location}"
  resource_group_name = "${azurerm_resource_group.storage.name}"
}

resource "azurerm_subnet" "subnet1" {
  name                 = "storage"
  resource_group_name  = "${azurerm_resource_group.storage.name}"
  virtual_network_name = "${azurerm_virtual_network.learning.name}"
  address_prefix       = "10.0.2.0/24"
}

resource "azurerm_network_interface" "test" {
  name                = "dc1"
  location            = "westus2"
  resource_group_name = "${azurerm_resource_group.storage.name}"

  ip_configuration {
    name                          = "dc1configuration1"
    subnet_id                     = "${azurerm_subnet.subnet1.id}"
    private_ip_address_allocation = "dynamic"
  }
}

resource "azurerm_storage_container" "packer" {
  name = "images"
  storage_account_name = "vibratopacker"
  resource_group_name = "${azurerm_resource_group.storage.name}"
  container_access_type = "private"
}

resource "azurerm_virtual_machine" "test" {
  name                  = "dc1"
  location              = "westus2"
  resource_group_name   = "${azurerm_resource_group.storage.name}"
  network_interface_ids = ["${azurerm_network_interface.test.id}"]
  vm_size               = "Standard_A0"

  delete_os_disk_on_termination = true
  delete_data_disks_on_termination = true

  storage_os_disk {
    name          = "osdisk"
    vhd_uri       = "https://vibratopacker.blob.core.windows.net/system/Microsoft.Compute/Images/windows-2016-datacenter/packer-osDisk.674f0bf3-82b0-4b68-8f6c-58d77cab822b.vhd"
    caching       = "ReadWrite"
    create_option = "FromImage"
  }

  os_profile {
    computer_name  = "hostname"
    admin_username = "testadmin"
    admin_password = "Password1234!"
  }
}
