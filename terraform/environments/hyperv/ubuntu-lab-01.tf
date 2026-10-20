# ubuntu-lab-01.tf — Ubuntu 24.04 lab VM
module "ubuntu_lab_01" {
  source = "../../modules/hyperv-vm"

  vm_name         = "ubuntu-lab-01"
  source_vhdx     = "${var.vhdx_source_path}\\ubuntu-24.04-cloudimg-amd64.vhdx"
  memory_mb       = 2048
  cpu_count       = 2
  switch_name     = hyperv_network_switch.lab_switch.name
  vhd_path        = var.vhd_path
  hyperv_host     = var.hyperv_host
  hyperv_user     = var.hyperv_user
  hyperv_password = var.hyperv_password
}