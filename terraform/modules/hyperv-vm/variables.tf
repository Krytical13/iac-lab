# modules/hyperv-vm/variables.tf
variable "vm_name" {
  description = "Name of the VM"
  type        = string
}

variable "source_vhdx" {
  description = "Full path to source VHDX golden image"
  type        = string
}

variable "memory_mb" {
  description = "Memory in MB"
  type        = number
  default     = 2048
}

variable "cpu_count" {
  description = "Number of virtual CPUs"
  type        = number
  default     = 2
}

variable "switch_name" {
  description = "Virtual switch to attach"
  type        = string
}

variable "vhd_path" {
  description = "Path for VM disks on the host"
  type        = string
}

variable "hyperv_host" {
  description = "Windows host for remote provisioner"
  type        = string
}

variable "hyperv_user" {
  description = "Windows admin user for remote provisioner"
  type        = string
}

variable "hyperv_password" {
  description = "Windows admin password for remote provisioner"
  type        = string
  sensitive   = true
}