# modules/hyperv-vm/outputs.tf
output "name" {
  description = "VM name"
  value       = hyperv_machine_instance.vm.name
}

output "ip" {
  description = "First IPv4 address the guest reported through integration services (null until it does)"
  value = try(
    [for a in hyperv_machine_instance.vm.network_adaptors[0].ip_addresses : a if can(regex("^\\d+\\.\\d+\\.\\d+\\.\\d+$", a))][0],
    null
  )
}
