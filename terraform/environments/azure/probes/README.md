# Guardrail probes

Two small ARM templates that ask Azure, without creating anything, whether the
guardrails in `../guardrails.tf` would let a request through. `az deployment
group validate` sends the request as far as the policy check and stops there.

Run them from `terraform/environments/azure`, signed in with `az login`, after
`terraform apply`. A new policy assignment can take some minutes to take effect.

| Command | Expected |
|---------|----------|
| `az deployment group validate -g rg-iac-lab --template-file probes/managed-identity.json` | passes: an allowed type in the lab region |
| `az deployment group validate -g rg-iac-lab --template-file probes/storage-account.json` | refused by `lab-allowed-resource-types` |
| `az deployment group validate -g rg-iac-lab --template-file probes/managed-identity.json --parameters location=westus2` | refused by `lab-allowed-locations` |

A refusal is an error that carries the code `RequestDisallowedByPolicy` and names
the policy assignment that refused the request. Run the first command as well:
it shows that a request the guardrails allow passes, so the two refusals come
from the policies and not from a broken sign-in.
