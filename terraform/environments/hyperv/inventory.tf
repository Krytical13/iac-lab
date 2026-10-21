# inventory.tf — write the Ansible inventory from the VMs' reported addresses
locals {
  lab_vms = [module.ubuntu_lab_01, module.rocky_lab_01, module.vault_lab_01, module.docker_01]
  vm_ips  = { for vm in local.lab_vms : vm.name => vm.ip if vm.ip != null }
  # The /24 the first VM's address belongs to, handed to Ansible as lab_network
  lab_network = length(local.vm_ips) > 0 ? cidrsubnet("${values(local.vm_ips)[0]}/24", 0, 0) : "0.0.0.0/0"
}

resource "local_file" "ansible_inventory" {
  content         = templatefile("${path.module}/hosts.yml.tftpl", { hosts = local.vm_ips, lab_network = local.lab_network })
  filename        = "${abspath(path.module)}/../../../ansible/inventories/hyperv-lab/hosts.yml"
  file_permission = "0644"
}
