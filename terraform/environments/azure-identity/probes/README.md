# Guardrail probe for the identity layer

One small ARM template that asks Azure, without creating anything, whether a
managed identity with a federated credential may go into the lab resource
group. `az deployment group validate` sends the request as far as the policy
check and stops there.

Run it from `terraform/environments/azure-identity`, signed in with `az login`,
before the first `terraform apply`.

| Command | Expected |
|---------|----------|
| `az deployment group validate -g rg-iac-lab --template-file probes/federated-identity.json` | passes: the identity is an allowed type in the lab region |

The template holds two resource types. The identity is on the allowed list of
the guardrails. The federated credential is a child of the identity and is not
on that list. The probe shows what the guardrails do with it before anything
real is created.

For a request that the guardrails refuse, use the probes of the other two
layers: `../azure/probes/storage-account.json` and
`../azure-network/probes/public-ip.json`.

The role assignment is not in the template. It needs the ID of a principal that
exists, and this probe creates nothing.
