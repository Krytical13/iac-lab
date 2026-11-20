# main.tf: provider configuration for the identity layer of the Azure lab
#
# A third root module with its own state. It builds inside the resource group
# that ../azure created. It cannot change the guardrails or the network: they
# are not in this state.
terraform {
  required_version = ">= 1.7.0" # the tests use mock_provider

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}

  subscription_id = var.subscription_id

  # Same choice as in ../azure and ../azure-network: the provider registers
  # nothing by itself. This layer uses two resource providers. Look at both
  # before the first apply:
  #   az provider show --namespace Microsoft.ManagedIdentity --query registrationState
  #   az provider show --namespace Microsoft.Authorization --query registrationState
  # If one is not registered, registering it is a change to the whole
  # subscription, so a person does it once, by hand, as in ../azure-network.
  resource_provider_registrations = "none"
}

# The resource group belongs to the guardrails layer. This layer only reads it.
data "azurerm_resource_group" "lab" {
  name = var.resource_group_name
}
