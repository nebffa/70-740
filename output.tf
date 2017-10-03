output "public_ips" {
  value = "${azurerm_public_ip.public_ip.*.ip_address}"
}
