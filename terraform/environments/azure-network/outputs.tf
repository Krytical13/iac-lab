# outputs.tf: what later code needs to find the network

output "virtual_network_id" {
  description = "Full ID of the virtual network."
  value       = azurerm_virtual_network.lab.id
}

output "subnets" {
  description = "Address range of each subnet, by name."
  value       = { for name, subnet in azurerm_subnet.lab : subnet.name => one(subnet.address_prefixes) }
}

output "network_security_group_id" {
  description = "Full ID of the network security group on both subnets."
  value       = azurerm_network_security_group.lab.id
}
