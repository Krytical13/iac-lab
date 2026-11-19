# variables.tf: inputs for the Azure guardrails. Real values go in terraform.tfvars,
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
  description = "The one resource group everything in the lab goes into."
  type        = string
  default     = "rg-iac-lab"
}

variable "location" {
  description = "Azure region for the resource group."
  type        = string
  default     = "eastus"
}

variable "allowed_locations" {
  description = "Regions the policy allows. Empty means only var.location."
  type        = list(string)
  default     = []
}

variable "allowed_resource_types" {
  description = "The only resource types the policy lets into the resource group. The lab found no charge for any of them; the budget is there in case that is wrong or changes."
  type        = list(string)
  default = [
    "Microsoft.ManagedIdentity/userAssignedIdentities",
    "Microsoft.Network/networkSecurityGroups",
    "Microsoft.Network/routeTables",
    "Microsoft.Network/virtualNetworks",
  ]

  # A seat belt for the list itself: these families always bill, so a typo or a
  # hurried edit cannot add one of them.
  validation {
    condition = alltrue([
      for t in var.allowed_resource_types :
      !can(regex("^microsoft\\.(compute|containerservice|sql|dbfor[a-z]+|web|cache|storage)/", lower(t)))
    ])
    error_message = "allowed_resource_types must not include a type from a family that bills (Compute, ContainerService, Sql, DBfor*, Web, Cache, Storage)."
  }
}

variable "policy_effect" {
  description = "What both policies do with a resource that breaks the rule. Audit only records it, Deny refuses it."
  type        = string
  default     = "Deny"

  validation {
    condition     = contains(["Audit", "Deny", "Disabled"], var.policy_effect)
    error_message = "policy_effect must be Audit, Deny or Disabled. These are the three effects the built-in definitions accept."
  }
}

variable "budget_amount" {
  description = "Monthly budget for the resource group, in the subscription's currency. The lab is meant to cost nothing, so this is a tripwire and not an allowance."
  type        = number
  default     = 1

  validation {
    condition     = var.budget_amount > 0
    error_message = "budget_amount must be above zero. Azure rejects a zero budget."
  }
}

variable "budget_start_date" {
  description = "First day the budget covers. Azure only accepts the first of a month, at midnight UTC."
  type        = string
  default     = "2026-11-01T00:00:00Z"

  validation {
    condition     = can(regex("^[0-9]{4}-(0[1-9]|1[0-2])-01T00:00:00Z$", var.budget_start_date))
    error_message = "budget_start_date must be the first of a month at midnight UTC, for example 2026-11-01T00:00:00Z."
  }
}

variable "alert_emails" {
  description = "Who gets the budget alert. No default: an alert nobody receives is not a guardrail."
  type        = list(string)

  validation {
    condition     = length(var.alert_emails) > 0 && alltrue([for a in var.alert_emails : can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", a))])
    error_message = "alert_emails needs at least one address, and every entry must look like an email address."
  }
}

variable "tags" {
  description = "Tags on the resource group."
  type        = map(string)
  default = {
    project    = "iac-lab"
    managed_by = "terraform"
  }
}
