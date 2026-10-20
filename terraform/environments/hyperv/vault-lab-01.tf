# vault-lab-01.tf — Ubuntu 24.04 VM that runs HashiCorp Vault in the Vault guide
module "vault_lab_01" {
  source = "../../modules/hyperv-vm"

  vm_name     = "vault-lab-01"
  source_vhdx = "${var.vhdx_source_path}\\ubuntu-24.04-cloudimg-amd64.vhdx"
  seed_iso    = "${var.seed_path}\\vault-lab-01-seed.iso"
  memory_mb   = 2048
  cpu_count   = 2
  switch_name = hyperv_network_switch.lab_switch.name
  vhd_path    = var.vhd_path
  vm_path     = var.vm_path
}
