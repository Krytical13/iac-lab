# outputs.tf — what the Ansible guide needs from this environment
output "vm_ips" {
  description = "VM name → IPv4 address reported by the guest"
  value       = local.vm_ips
}

output "ansible_inventory_path" {
  description = "Inventory file Terraform wrote from those addresses"
  value       = local_file.ansible_inventory.filename
}
