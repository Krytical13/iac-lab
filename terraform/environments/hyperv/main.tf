# main.tf — Hyper-V provider configuration
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    hyperv = {
      source  = "taliesins/hyperv"
      version = "~> 1.2"
    }
  }
}

provider "hyperv" {
  user     = var.hyperv_user
  password = var.hyperv_password
  host     = var.hyperv_host
  port     = var.hyperv_port
  https    = true
  insecure = true # Self-signed cert from setup-winrm.ps1
  timeout  = "60s"
}

# Virtual switch — shared by all VMs
resource "hyperv_network_switch" "lab_switch" {
  name                = var.switch_name
  switch_type         = "Internal"
  allow_management_os = true
}