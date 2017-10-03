variable "azure_subscription_id" {}
variable "azure_client_id" {}
variable "azure_client_secret" {}
variable "azure_tenant_id" {}
variable "location" {
  default = "southeastasia"
}
variable "default_resource_group_name" {
  default = "learning"
}
variable "packer_storage_account_name" {
  default = "vibratopacker"
}

variable "admin_username" {
  default = "storageadmin"
}
variable "admin_password" {}

variable "image_uri" {}


provider "azurerm" {
  subscription_id = "${var.azure_subscription_id}"
  client_id       = "${var.azure_client_id}"
  client_secret   = "${var.azure_client_secret}"
  tenant_id       = "${var.azure_tenant_id}"
}

resource "azurerm_virtual_network" "learning" {
  name                = "storage_network"
  address_space       = ["10.0.0.0/16"]
  location            = "${var.location}"
  resource_group_name = "${var.default_resource_group_name}"
}

resource "azurerm_subnet" "subnet1" {
  name                 = "storage"
  resource_group_name  = "${var.default_resource_group_name}"
  virtual_network_name = "${azurerm_virtual_network.learning.name}"
  address_prefix       = "10.0.2.0/24"
}

resource "azurerm_public_ip" "public_ip" {
  name = "public_ip${count.index}"
  location = "${var.location}"
  resource_group_name = "${var.default_resource_group_name}"
  public_ip_address_allocation = "static"
  count = 4
}

resource "azurerm_network_interface" "network_interface" {
  name                = "network_interface${count.index}"
  location            = "${var.location}"
  resource_group_name = "${var.default_resource_group_name}"
  count = 4

  ip_configuration {
    name                          = "ip_configuration${count.index}"
    subnet_id                     = "${azurerm_subnet.subnet1.id}"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id = "${azurerm_public_ip.public_ip.*.id[count.index]}"
  }
}

resource "azurerm_storage_account" "learning" {
  name = "vibratolearning"
  location = "${var.location}"
  resource_group_name = "${var.default_resource_group_name}"
  account_type        = "Standard_LRS"
}

resource "azurerm_storage_container" "packer" {
  name = "system"
  storage_account_name = "${azurerm_storage_account.learning.name}"
  resource_group_name = "${var.default_resource_group_name}"
  container_access_type = "private"
}

resource "azurerm_storage_container" "windows-storage" {
  name = "windows-storage"
  storage_account_name = "${azurerm_storage_account.learning.name}"
  resource_group_name = "${var.default_resource_group_name}"
  container_access_type = "private"
}

resource "azurerm_storage_blob" "image" {
  name = "windows-2016-datacenter.vhd"

  resource_group_name    = "${var.default_resource_group_name}"
  storage_account_name   = "${azurerm_storage_account.learning.name}"
  storage_container_name = "${azurerm_storage_container.windows-storage.name}"

  source_uri = "${var.image_uri}"
}

resource "azurerm_virtual_machine" "vms" {
  name                  = "vm${count.index}"
  location              = "${var.location}"
  resource_group_name   = "${var.default_resource_group_name}"
  network_interface_ids = ["${azurerm_network_interface.network_interface.*.id[count.index]}"]
  vm_size               = "Standard_A3"

  count = 4

  delete_os_disk_on_termination = true
  delete_data_disks_on_termination = true

  storage_os_disk {
    name          = "osdisk"
    image_uri = "${azurerm_storage_account.learning.primary_blob_endpoint}${azurerm_storage_container.windows-storage.name}/${azurerm_storage_blob.image.name}"
    vhd_uri       = "${azurerm_storage_account.learning.primary_blob_endpoint}${azurerm_storage_container.windows-storage.name}/storage.${count.index}.vhd"
    caching       = "ReadWrite"
    create_option = "FromImage"
    os_type = "windows"
  }

  os_profile {
    computer_name = "storage${count.index}"
    admin_username = "${var.admin_username}"
    admin_password = "${var.admin_password}"
  }
}
