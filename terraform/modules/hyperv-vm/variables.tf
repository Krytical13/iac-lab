# modules/hyperv-vm/variables.tf
variable "vm_name" {
  description = "Name of the VM (also its hostname via cloud-init)"
  type        = string
}

variable "source_vhdx" {
  description = "Full host path to the golden VHDX this VM's disk is copied from"
  type        = string
}

variable "seed_iso" {
  description = "Full host path to this VM's cloud-init seed ISO (volume id cidata)"
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
  description = "Host directory for the VM's disk file"
  type        = string
}

variable "vm_path" {
  description = "Host directory for the VM's configuration, smart paging and checkpoint files"
  type        = string
}
