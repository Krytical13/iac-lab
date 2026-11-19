# variables.tf: inputs for the network layer. Real values go in terraform.tfvars,
# which git ignores. Copy terraform.tfvars.example to start.

variable "subscription_id" {
  description = "The subscription the lab resource group lives in."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$", var.subscription_id))
    error_message = "subscription_id must be a GUID, as printed by: az account show --query id"
  }
}

variable "resource_group_name" {
  description = "The resource group the guardrails layer created. This layer reads it and builds inside it."
  type        = string
  default     = "rg-iac-lab"
}

# No default on purpose. Registering a resource provider changes the
# subscription, so the answer has to be written down by a person:
#   az provider show --namespace Microsoft.Network --query registrationState --output tsv
# NotRegistered -> true. Registered -> false.
variable "register_network_provider" {
  description = "Whether this code registers the resource provider Microsoft.Network on the subscription."
  type        = bool
}

variable "vnet_name" {
  description = "Name of the virtual network."
  type        = string
  default     = "vnet-iac-lab"
}

variable "address_space" {
  description = "Address range of the virtual network. A private /16; the subnets are /24s cut out of it."
  type        = string
  default     = "10.20.0.0/16"

  validation {
    condition     = can(cidrhost(var.address_space, 0)) && endswith(var.address_space, "/16")
    error_message = "address_space must be an IPv4 range in CIDR form with a /16 prefix, for example 10.20.0.0/16."
  }

  # A seat belt: a range that is in use on the internet would shadow the real
  # owners of those addresses for everything inside the network.
  validation {
    condition     = can(regex("^(10\\.|172\\.(1[6-9]|2[0-9]|3[01])\\.|192\\.168\\.)", var.address_space))
    error_message = "address_space must be a private range: inside 10.0.0.0/8, 172.16.0.0/12 or 192.168.0.0/16."
  }
}

variable "data_port" {
  description = "The one TCP port the app subnet may reach in the data subnet."
  type        = number
  default     = 5432

  validation {
    condition     = var.data_port >= 1 && var.data_port <= 65535 && floor(var.data_port) == var.data_port
    error_message = "data_port must be a whole number from 1 to 65535."
  }
}

variable "tags" {
  description = "Tags on the virtual network and the network security group."
  type        = map(string)
  default = {
    project    = "iac-lab"
    managed_by = "terraform"
  }
}
