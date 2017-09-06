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

resource "azurerm_storage_account" "packer" {
  name                = "vibratopacker"
  resource_group_name = "${azurerm_resource_group.storage.name}"
  location            = "westus2"
  account_type        = "Standard_LRS"
}

resource "azurerm_storage_container" "packer" {
  name = "system"
  storage_account_name = "${azurerm_storage_account.packer.name}"
  resource_group_name = "${azurerm_resource_group.storage.name}"
  container_access_type = "private"
}

resource "azurerm_storage_blob" "image" {
  name = "windows-2016-datacenter.vhd"

  resource_group_name    = "${azurerm_resource_group.storage.name}"
  storage_account_name   = "${azurerm_storage_account.packer.name}"
  storage_container_name = "${azurerm_storage_container.packer.name}"

  source_uri = "https://vibratopacker.blob.core.windows.net/system/Microsoft.Compute/Images/windows-2016-datacenter/packer-osDisk.674f0bf3-82b0-4b68-8f6c-58d77cab822b.vhd"
}

#https://vibratopacker.blob.core.windows.net/system/Microsoft.Compute/Images/windows-2016-datacenter/packer-osDisk.674f0bf3-82b0-4b68-8f6c-58d77cab822b.vhd
resource "azurerm_virtual_machine" "test" {
  name                  = "dc1"
  location              = "westus2"
  resource_group_name   = "${azurerm_resource_group.storage.name}"
  network_interface_ids = ["${azurerm_network_interface.test.id}"]
  vm_size               = "Standard_A0"

  storage_os_disk {
    name          = "osdisk"
    image_uri = "${azurerm_storage_account.packer.primary_blob_endpoint}system/windows-2016-datacenter.vhd"
    vhd_uri       = "${azurerm_storage_account.packer.primary_blob_endpoint}system/windows-2016-datacenter2.vhd"
    caching       = "ReadWrite"
    create_option = "FromImage"
    os_type = "windows"
  }

  os_profile {
    computer_name = "dc1"
    admin_username = "testadmin"
    admin_password = "Password1234!"
  }
}
