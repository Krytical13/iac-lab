# _template.tf.example — copy this file to add a VM
# 1. Copy: cp _template.tf.example my-server-01.tf
# 2. Replace every CHANGEME value
# 3. Build its seed: scripts/make-seed.sh my-server-01 ubuntu ~/.ssh/lab_key.pub, then scripts/push-images.sh
# 4. Run: terraform plan, then terraform apply

module "docker_01" {
  source = "../../modules/hyperv-vm"

  vm_name     = "docker-01"
  source_vhdx = "${var.vhdx_source_path}\\ubuntu-24.04-cloudimg-amd64.vhdx" # ubuntu-24.04-cloudimg-amd64.vhdx or rocky-9-cloudimg-amd64.vhdx
  seed_iso    = "${var.seed_path}\\docker-01-seed.iso"
  memory_mb   = 2048
  cpu_count   = 2
  switch_name = hyperv_network_switch.lab_switch.name
  vhd_path    = var.vhd_path
  vm_path     = var.vm_path
}
