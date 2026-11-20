# outputs.tf: what a workflow needs to sign in as the identity
#
# These are IDs. They say who to sign in as. The proof that a job may do so is
# the token GitHub signs for it, and that is not stored anywhere.

output "client_id" {
  description = "Client ID of the identity. A workflow gives it to the sign-in step."
  value       = azurerm_user_assigned_identity.pipeline.client_id
}

output "tenant_id" {
  description = "The Microsoft Entra tenant the identity lives in."
  value       = azurerm_user_assigned_identity.pipeline.tenant_id
}

output "principal_id" {
  description = "Object ID of the identity's service principal. Role assignments name this ID."
  value       = azurerm_user_assigned_identity.pipeline.principal_id
}

output "github_subject" {
  description = "The one token subject the identity accepts."
  value       = local.github_subject
}
