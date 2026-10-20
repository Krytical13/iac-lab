# inventory.tf — write the Ansible inventory from the VMs' reported addresses
locals {
  lab_vms = [module.ubuntu_lab_01, module.rocky_lab_01, module.vault_lab_01]
  vm_ips  = { for vm in local.lab_vms : vm.name => vm.ip if vm.ip != null }
}

resource "local_file" "ansible_inventory" {
  content         = templatefile("${path.module}/hosts.yml.tftpl", { hosts = local.vm_ips })
  filename        = "${abspath(path.module)}/../../../ansible/inventories/hyperv-lab/hosts.yml"
  file_permission = "0644"
}
