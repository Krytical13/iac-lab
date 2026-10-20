# main.tf — provider configuration and the switch the lab VMs share
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    hyperv = {
      source  = "taliesins/hyperv"
      version = "~> 1.2.0" # patch releases only
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

provider "hyperv" {
  host     = var.hyperv_host
  port     = var.hyperv_port
  user     = var.hyperv_user
  password = var.hyperv_password
  https    = true
  insecure = var.hyperv_insecure # self-signed certificate from setup-winrm.ps1
  use_ntlm = true                # local account; Basic auth stays off on the host
  timeout  = "60s"
}

# External switch: VMs sit on the same LAN as the host and get DHCP from your router.
# allow_management_os keeps the host's own network on the adapter (through a vEthernet).
resource "hyperv_network_switch" "lab_switch" {
  name                = var.switch_name
  switch_type         = "External"
  net_adapter_names   = [var.host_nic]
  allow_management_os = true

  # Windows derives these from the physical adapter (bandwidth mode, 10 % reserve,
  # VMMQ/vRSS). Leave them to Windows: without this, importing a switch made with
  # New-VMSwitch plans a replacement because the provider's defaults differ.
  lifecycle {
    # Destroying the switch drops the host's network and moves its IP back to the
    # physical adapter. `terraform destroy` therefore refuses until you remove this
    # line; destroy VMs with -target (Module 05) instead.
    prevent_destroy = true
    ignore_changes = [
      minimum_bandwidth_mode,
      default_flow_minimum_bandwidth_absolute,
      default_queue_vmmq_enabled,
      default_queue_vrss_enabled,
    ]
  }
}
