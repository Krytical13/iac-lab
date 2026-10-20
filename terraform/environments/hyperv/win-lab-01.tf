# win-lab-01.tf — Windows Server 2022 lab VM
module "win_lab_01" {
  source = "../../modules/hyperv-vm"

  vm_name         = "win-lab-01"
  source_vhdx     = "${var.vhdx_source_path}\\win-server-2022.vhdx"
  memory_mb       = 4096 # Windows needs more RAM
  cpu_count       = 2
  switch_name     = hyperv_network_switch.lab_switch.name
  vhd_path        = var.vhd_path
  hyperv_host     = var.hyperv_host
  hyperv_user     = var.hyperv_user
  hyperv_password = var.hyperv_password
}