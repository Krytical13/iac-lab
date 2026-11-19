# outputs.tf: what later code and the checks need to find the guardrails

output "resource_group_name" {
  description = "Name of the lab resource group."
  value       = azurerm_resource_group.lab.name
}

output "resource_group_id" {
  description = "Full ID of the lab resource group."
  value       = azurerm_resource_group.lab.id
}

output "allowed_locations" {
  description = "Regions the location policy lets in."
  value       = local.allowed_locations
}
