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
# not a setting to inherit from an example. And only GitHub knows how it names
# that repository in a token: one created after 15 July 2026 gets the ID of its
# owner and its own ID next to the two names, so that a name someone gives up
# and another person takes does not carry the trust along. Ask GitHub and paste
# the answer:
#   gh api repos/OWNER/NAME/actions/oidc/customization/sub --jq .sub_claim_prefix
variable "github_subject_prefix" {
  description = "The one GitHub repository whose workflows may sign in as the identity, written the way GitHub starts the subject of its tokens."
  type        = string

  # A seat belt: Microsoft's page on federated credentials says wildcard
  # characters are not supported in any of their values, so a pattern such as
  # repo:octo-org/* cannot stand for many repositories.
  validation {
    condition     = can(regex("^repo:[A-Za-z0-9][A-Za-z0-9-]*(@[0-9]+/[A-Za-z0-9._-]+@[0-9]+|/[A-Za-z0-9._-]+)$", var.github_subject_prefix))
    error_message = "github_subject_prefix must be one repository as GitHub writes it: repo:octo-org@123456/octo-repo@456789, or repo:octo-org/octo-repo for a repository that still goes by names only. No URL, no wildcard."
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
