# rocky-lab-01.tf — Rocky Linux 9 (RHEL) lab VM
module "rocky_lab_01" {
  source = "../../modules/hyperv-vm"

  vm_name         = "rocky-lab-01"
  source_vhdx     = "${var.vhdx_source_path}\\rocky-9-cloudimg-amd64.vhdx"
  memory_mb       = 2048
  cpu_count       = 2
  switch_name     = hyperv_network_switch.lab_switch.name
  vhd_path        = var.vhd_path
  hyperv_host     = var.hyperv_host
  hyperv_user     = var.hyperv_user
  hyperv_password = var.hyperv_password
}