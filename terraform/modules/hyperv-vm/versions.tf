# modules/hyperv-vm/versions.tf
# A module names the providers it uses but leaves the version to the root module:
# without this block Terraform would look for "hashicorp/hyperv", which does not exist.
terraform {
  required_providers {
    hyperv = {
      source = "taliesins/hyperv"
    }
  }
}
