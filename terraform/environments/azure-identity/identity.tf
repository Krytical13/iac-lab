# identity.tf: who a pipeline is, what it may do, and who may act as it
#
# Three resources, one question each:
#   the identity               who is this?
#   the role assignment        what may it do, and where?
#   the federated credential   whose token is accepted as a sign-in?
# There is no password, key or certificate in this file, and so there is none
# in the state.

locals {
  # GitHub puts this string in the "sub" claim of the token it gives to a job
  # that runs in the named environment of the named repository. Azure accepts
  # a token only when its claim is the same string as the subject stored below.
  # The first part is GitHub's own wording for the repository (variables.tf).
  github_subject = "${var.github_subject_prefix}:environment:${var.github_environment}"
}

resource "azurerm_user_assigned_identity" "pipeline" {
  name                = var.identity_name
  resource_group_name = data.azurerm_resource_group.lab.name
  location            = data.azurerm_resource_group.lab.location
  tags                = var.tags
}

# Reader on the lab resource group and nothing else. The scope is the resource
# group, not the subscription, so the role covers what is in the lab and not
# the rest. Reader can look and cannot change.
resource "azurerm_role_assignment" "reader" {
  scope                = data.azurerm_resource_group.lab.id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.pipeline.principal_id

  # The identity is new in this same apply. Microsoft's troubleshooting page
  # says a role assignment to a new principal can fail on a replication delay,
  # and that setting the type of the principal is the way around it.
  principal_type = "ServicePrincipal"
}

resource "azurerm_federated_identity_credential" "github" {
  name                      = "github-${var.github_environment}"
  user_assigned_identity_id = azurerm_user_assigned_identity.pipeline.id

  issuer   = "https://token.actions.githubusercontent.com"
  subject  = local.github_subject
  audience = ["api://AzureADTokenExchange"]
}
