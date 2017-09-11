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


resource "azurerm_resource_group" "learning" {
  name = "learning"
  location = "westus2"
}

resource "azurerm_virtual_network" "learning" {
  name                = "storage_network"
  address_space       = ["10.0.0.0/16"]
  location            = "${azurerm_resource_group.learning.location}"
  resource_group_name = "${azurerm_resource_group.learning.name}"
}

resource "azurerm_subnet" "subnet1" {
  name                 = "storage"
  resource_group_name  = "${azurerm_resource_group.learning.name}"
  virtual_network_name = "${azurerm_virtual_network.learning.name}"
  address_prefix       = "10.0.2.0/24"
}

resource "azurerm_public_ip" "dc1" {
  name = "dc1publicip"
  location = "westus2"
  resource_group_name = "${azurerm_resource_group.learning.name}"
  public_ip_address_allocation = "static"
  count = 4
}

resource "azurerm_network_interface" "dc1" {
  name                = "dc1${count.index}"
  location            = "westus2"
  resource_group_name = "${azurerm_resource_group.learning.name}"

  count = 4

  ip_configuration {
    name                          = "dc1configuration1${count.index}"
    subnet_id                     = "${azurerm_subnet.subnet1.id}"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id = "${azurerm_public_ip.dc1.*.id[count.index]}"
  }
}

resource "azurerm_storage_account" "packer" {
  name                = "vibratopacker"
  resource_group_name = "${azurerm_resource_group.learning.name}"
  location            = "westus2"
  account_type        = "Standard_LRS"
}

resource "azurerm_storage_container" "packer" {
  name = "system"
  storage_account_name = "${azurerm_storage_account.packer.name}"
  resource_group_name = "${azurerm_resource_group.learning.name}"
  container_access_type = "private"
}

resource "azurerm_storage_container" "windows-storage" {
  name = "windows-storage"
  storage_account_name = "${azurerm_storage_account.packer.name}"
  resource_group_name = "${azurerm_resource_group.learning.name}"
  container_access_type = "private"
}

resource "azurerm_storage_blob" "image" {
  name = "windows-2016-datacenter.vhd"

  resource_group_name    = "${azurerm_resource_group.learning.name}"
  storage_account_name   = "${azurerm_storage_account.packer.name}"
  storage_container_name = "${azurerm_storage_container.windows-storage.name}"

  source_uri = "https://vibratopacker.blob.core.windows.net/system/Microsoft.Compute/Images/windows-2016-datacenter/packer-osDisk.2ab8f02e-666a-42ca-8bc0-f90bd7a5cf81.vhd"
}

resource "azurerm_virtual_machine" "dc1" {
  name                  = "dc1"
  location              = "westus2"
  resource_group_name   = "${azurerm_resource_group.learning.name}"
  network_interface_ids = ["${azurerm_network_interface.dc1.*.id[count.index]}"]
  vm_size               = "Standard_A3"

  count = 4

  delete_os_disk_on_termination = true
  delete_data_disks_on_termination = true

  storage_os_disk {
    name          = "osdisk"
    image_uri = "${azurerm_storage_account.packer.primary_blob_endpoint}${azurerm_storage_container.windows-storage.name}/${azurerm_storage_blob.image.name}"
    vhd_uri       = "${azurerm_storage_account.packer.primary_blob_endpoint}${azurerm_storage_container.windows-storage.name}/dc1.${count.index}.vhd"
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
