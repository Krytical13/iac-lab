# Guardrail probes for the network layer

Two small ARM templates that ask Azure, without creating anything, whether the
guardrails still hold now that the resource group has a network in it. `az
deployment group validate` sends the request as far as the policy check and
stops there.

Run them from `terraform/environments/azure-network`, signed in with `az login`,
after `terraform apply`.

| Command | Expected |
|---------|----------|
| `az deployment group validate -g rg-iac-lab --template-file probes/security-group.json` | passes: an allowed type in the lab region |
| `az deployment group validate -g rg-iac-lab --template-file probes/public-ip.json` | refused by `lab-allowed-resource-types` |

A refusal is an error that carries the code `RequestDisallowedByPolicy` and names
the policy assignment that refused the request. Run the first command as well:
it shows that a network request the guardrails allow passes, so the refusal
comes from the policy and not from a broken sign-in or a missing registration.
