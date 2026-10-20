# variables.tf — environment-specific inputs (values go in terraform.tfvars, which is gitignored)
variable "hyperv_host" {
  description = "Hyper-V host: IPv4 address or DNS name"
  type        = string
  validation {
    condition     = can(regex("^[A-Za-z0-9.-]+$", var.hyperv_host))
    error_message = "hyperv_host must be an IPv4 address or a hostname."
  }
}

variable "hyperv_user" {
  description = "Local administrator on the host used over WinRM"
  type        = string
}

variable "hyperv_password" {
  description = "Password for hyperv_user"
  type        = string
  sensitive   = true
}

variable "hyperv_port" {
  description = "WinRM HTTPS port"
  type        = number
  default     = 5986
}

variable "hyperv_insecure" {
  description = "Skip TLS verification (the listener uses a self-signed certificate)"
  type        = bool
  default     = true
}

variable "host_nic" {
  description = "Name of the physical adapter from Get-NetAdapter, e.g. Ethernet"
  type        = string
  validation {
    condition     = length(var.host_nic) > 0 && length(var.host_nic) <= 64
    error_message = "host_nic must be an adapter name from Get-NetAdapter"
  }
}

variable "switch_name" {
  description = "Name of the External virtual switch"
  type        = string
  default     = "Lab-External"
}

variable "vhdx_source_path" {
  description = "Host directory holding the golden VHDX images"
  type        = string
  default     = "C:\\HyperV\\Images"
}

variable "seed_path" {
  description = "Host directory holding the per-VM cloud-init seed ISOs"
  type        = string
  default     = "C:\\HyperV\\Images\\seeds"
}

variable "vhd_path" {
  description = "Host directory for the VMs' disk files"
  type        = string
  default     = "C:\\HyperV\\VHDs"
}

variable "vm_path" {
  description = "Host directory for VM configuration, smart paging and checkpoint files"
  type        = string
  default     = "C:\\HyperV\\VMs"
}
