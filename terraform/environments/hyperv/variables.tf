# variables.tf — Environment-specific variables for Hyper-V
variable "hyperv_host" {
  description = "Windows host IP or hostname"
  type        = string
  validation {
    condition     = can(regex("^[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}$", var.hyperv_host))
    error_message = "Must be a valid IPv4 address."
  }
}

variable "hyperv_user" {
  description = "Windows admin username"
  type        = string
}

variable "hyperv_password" {
  description = "Windows admin password"
  type        = string
  sensitive   = true
}

variable "hyperv_port" {
  description = "WinRM HTTPS port"
  type        = number
  default     = 5986
}

variable "switch_name" {
  description = "Hyper-V virtual switch name"
  type        = string
  default     = "LabSwitch"
}

variable "vhdx_source_path" {
  description = "Path to golden VHDX images on the Windows host"
  type        = string
  default     = "C:\\HyperV\\Images"
}

variable "vm_path" {
  description = "Path for VM configuration files"
  type        = string
  default     = "C:\\HyperV\\VMs"
}

variable "vhd_path" {
  description = "Path for VM virtual hard disks"
  type        = string
  default     = "C:\\HyperV\\VHDs"
}