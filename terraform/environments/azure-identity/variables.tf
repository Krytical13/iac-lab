# variables.tf: inputs for the identity layer. Real values go in terraform.tfvars,
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

variable "identity_name" {
  description = "Name of the user-assigned managed identity a pipeline signs in as."
  type        = string
  default     = "id-iac-lab-pipeline"
}

# No default on purpose. Which repository may act as the identity is a decision,
# not a setting to inherit from an example.
variable "github_repository" {
  description = "The one GitHub repository whose workflows may sign in as the identity, written owner/name."
  type        = string

  # A seat belt: Microsoft's page on federated credentials says wildcard
  # characters are not supported in any of their values, so a pattern such as
  # octo-org/* cannot stand for many repositories.
  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9-]*/[A-Za-z0-9._-]+$", var.github_repository))
    error_message = "github_repository must be one repository written owner/name, for example octo-org/octo-repo. No URL, no wildcard."
  }
}

variable "github_environment" {
  description = "The GitHub environment a job must run in before GitHub gives it a token that Azure accepts."
  type        = string
  default     = "azure-lab"

  # The lab's own rule, stricter than GitHub's: lower case and no spaces, so
  # the name is the same string in the workflow, in the token and here.
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9._-]*$", var.github_environment))
    error_message = "github_environment must start with a lower-case letter or a digit and hold only lower-case letters, digits, dots, underscores and hyphens."
  }
}

variable "tags" {
  description = "Tags on the managed identity."
  type        = map(string)
  default = {
    project    = "iac-lab"
    managed_by = "terraform"
  }
}
