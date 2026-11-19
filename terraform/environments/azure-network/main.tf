# main.tf: provider configuration for the network layer of the Azure lab
#
# A second root module with its own state. It builds inside the resource group
# that ../azure created, and it cannot change the guardrails: they are not in
# this state.
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

  # Same choice as in ../azure: the provider registers nothing by itself. This
  # layer needs one resource provider, Microsoft.Network. Registering it is a
  # change to the subscription, so a person does it once, by hand:
  #   az provider register --namespace Microsoft.Network --wait
  # It is not a resource in this code on purpose. A resource would be removed
  # again by a destroy, and a registration belongs to the whole subscription.
  resource_provider_registrations = "none"
}

# The resource group belongs to the guardrails layer. This layer only reads it.
data "azurerm_resource_group" "lab" {
  name = var.resource_group_name
}
