# tests/identity.tftest.hcl: what the identity layer is made of
#
# The azurerm provider is mocked, so this needs no Azure account and no sign-in,
# and it creates nothing. A mocked provider makes up values for anything Azure
# would answer. Two values get a real shape below: the resource group this layer
# reads, and the ID of the identity, which the federated credential checks
# before it accepts it.
mock_provider "azurerm" {
  mock_data "azurerm_resource_group" {
    defaults = {
      id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-iac-lab"
      location = "eastus"
    }
  }

  mock_resource "azurerm_user_assigned_identity" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-iac-lab/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-iac-lab-pipeline"
    }
  }
}

variables {
  subscription_id   = "00000000-0000-0000-0000-000000000000"
  github_repository = "octo-org/octo-repo"
}

run "identity_goes_into_the_group_it_reads" {
  command = apply

  assert {
    condition     = azurerm_user_assigned_identity.pipeline.resource_group_name == "rg-iac-lab"
    error_message = "The identity must go into the resource group named by var.resource_group_name."
  }

  assert {
    condition     = azurerm_user_assigned_identity.pipeline.location == "eastus"
    error_message = "The identity must take its region from the resource group, not from a value of its own."
  }

  assert {
    condition     = azurerm_user_assigned_identity.pipeline.tags["managed_by"] == "terraform"
    error_message = "The identity must carry the managed_by tag, so nobody edits it by hand."
  }
}

run "role_is_reader_on_the_resource_group_and_no_wider" {
  command = apply

  assert {
    condition     = azurerm_role_assignment.reader.role_definition_name == "Reader"
    error_message = "The identity must get the Reader role. A role that can change things is a decision for a later layer."
  }

  assert {
    condition     = azurerm_role_assignment.reader.scope == data.azurerm_resource_group.lab.id
    error_message = "The role must be assigned on the lab resource group."
  }

  assert {
    condition     = endswith(azurerm_role_assignment.reader.scope, "/resourceGroups/rg-iac-lab")
    error_message = "The scope must end at the resource group. A scope that ends at the subscription covers everything in it."
  }

  assert {
    condition     = azurerm_role_assignment.reader.principal_id == azurerm_user_assigned_identity.pipeline.principal_id
    error_message = "The role must go to the identity of this layer and to nobody else."
  }

  assert {
    condition     = azurerm_role_assignment.reader.principal_type == "ServicePrincipal"
    error_message = "principal_type must be set: the identity is new in the same apply."
  }
}

run "credential_trusts_one_repository_in_one_environment" {
  command = apply

  assert {
    condition     = azurerm_federated_identity_credential.github.subject == "repo:octo-org/octo-repo:environment:azure-lab"
    error_message = "The subject must name the repository and the environment, in the form GitHub puts in the token."
  }

  assert {
    condition     = azurerm_federated_identity_credential.github.issuer == "https://token.actions.githubusercontent.com"
    error_message = "The issuer must be GitHub's token service."
  }

  assert {
    condition     = azurerm_federated_identity_credential.github.audience == tolist(["api://AzureADTokenExchange"])
    error_message = "The audience must be the one value Microsoft recommends for a token exchange."
  }

  assert {
    condition     = azurerm_federated_identity_credential.github.user_assigned_identity_id == azurerm_user_assigned_identity.pipeline.id
    error_message = "The credential must belong to the identity of this layer."
  }

  assert {
    condition     = output.github_subject == azurerm_federated_identity_credential.github.subject
    error_message = "The github_subject output must be the subject that was stored."
  }
}

run "another_environment_is_another_subject" {
  command = apply

  variables {
    github_environment = "production"
  }

  assert {
    condition     = azurerm_federated_identity_credential.github.subject == "repo:octo-org/octo-repo:environment:production"
    error_message = "The subject must follow var.github_environment."
  }

  assert {
    condition     = azurerm_federated_identity_credential.github.name == "github-production"
    error_message = "The name of the credential must say which environment it trusts."
  }
}
