# iac-lab

A self-paced Infrastructure as Code lab: Terraform builds Linux VMs on a Hyper-V host, Ansible configures them, and HashiCorp Vault issues their secrets. This repo holds the runnable code; the guides that walk you through it live at <https://k13.io/lab/>. Start by forking this repo and cloning your fork onto a Linux control node, then follow the Terraform guide from its first module. It was written by a sysadmin learning these tools in a homelab, so treat it as a learning lab, not a production reference.

## Layout

| Path | What it holds |
|------|---------------|
| `terraform/environments/hyperv/` | Root module: provider, External switch, one file per lab VM, Ansible inventory output |
| `terraform/modules/hyperv-vm/` | Reusable module: copies a golden VHDX, attaches a cloud-init seed, waits for the IP |
| `cloud-init/` | NoCloud user-data and meta-data templates for the seed ISOs |
| `scripts/` | Host and control-node helpers (`setup-winrm.ps1`, image preparation, pushing images) |
| `ansible/` | Roles, playbooks, inventories and examples for the Ansible guide (and the `vault_server` role) |
| `vault/` | Policies, SSH role definitions, Vault Agent config and helper scripts for the Vault guide |
| `terraform/environments/hyperv/tests/` | Unit tests for the module and the environment (`terraform test`, every provider mocked) |
| `terraform/environments/azure/` | Root module for an Azure subscription: one lab resource group with cost guardrails (two policy assignments and a budget), its own unit tests in `tests/`, and no-create probes in `probes/` |
| `terraform/environments/azure-network/` | A second root module with its own state, inside that resource group: one virtual network, two private subnets and a network security group, with unit tests in `tests/` and no-create probes in `probes/` |
| `terraform/environments/azure-identity/` | A third root module with its own state, inside the same resource group: one managed identity for a pipeline, the Reader role on the resource group, and a federated credential that trusts one GitHub repository in one environment, with unit tests in `tests/` and a no-create probe in `probes/`. The repository is named the way GitHub starts the subject of its tokens (`github_subject_prefix`); the example file has the command that prints it |
| `terraform/environments/azure-network/pipeline/` | Import blocks for the `azure-plan` workflow, kept outside the root module so the unit tests still run. `tests/tf-imports.sh` checks them |
| `.github/workflows/` | `validate.yml` checks the code on every push and pull request. `azure-plan.yml` signs in to Azure as the managed identity and plans the network layer; it starts only by hand and never applies |
| `terraform/examples/vault-secrets/` | A small root module showing a Vault data source next to an ephemeral resource |
| `tests/` | Small shell and PowerShell checks the lab was verified with |

## Terraform tests

`tests/tf-test.sh` runs `terraform test` in the Hyper-V root module. The test files mock every provider, so the tests need no Hyper-V host, no credentials and no state, and they create nothing: they run on any machine that has Terraform. The CI workflow runs them on every push and pull request, after `fmt` and `validate`.

`tests/tf-test.sh azure`, `tests/tf-test.sh azure-network` and `tests/tf-test.sh azure-identity` do the same for the three Azure root modules. Those tests mock the `azurerm` provider, so they need no Azure account and no sign-in.

## The Azure plan job

`.github/workflows/azure-plan.yml` runs only when you start it (Actions > azure-plan > Run workflow, or `gh workflow run azure-plan.yml`). It signs in with a token from GitHub as the identity of `azure-identity`, lists the lab resource group, checks that a change is refused, and plans `azure-network` from an empty state with the import blocks in `pipeline/`. A clean run ends with `Plan: 8 to import, 0 to add, 0 to change, 0 to destroy.` It needs the three Azure layers applied, an environment named `azure-lab` in your fork with yourself as required reviewer, and three secrets in that environment; the comment at the top of the workflow file lists them. The log of a public repository is public, so the job prints names and a summary and keeps IDs and error texts on the runner.

## Ansible

Run every Ansible command from `ansible/`, where `ansible.cfg` lives. Install what the roles need once (`ansible-galaxy install -r requirements.yml`), create `.vault_pass` (the lab password is `labpassword`; the file is gitignored), then `ansible-playbook playbooks/base.yml` configures the VMs Terraform built. `tests/ansible-static.sh` is the lint and syntax gate the CI workflow runs.

## Vault

`ansible-playbook playbooks/vault.yml` installs Vault on the `vault_servers` host (open its API port first: `playbooks/base.yml --tags firewall --limit vault_servers`). Every policy, role definition and config the guide applies is under `vault/`; run the `vault` CLI from that directory on the control node with `VAULT_ADDR` pointing at the server. Generated material (CA certificates, agent credentials, `init.txt`, snapshots) goes to the gitignored `vault/local/`. `tests/vault-static.sh` smoke-tests all of it against a throwaway dev server; `tests/vault-lab.sh` checks the running lab.

Example values in this repo use documentation addresses (`192.168.1.x`) and the hostname `hyperv-host`. Your own host, account and paths go in `terraform/environments/hyperv/terraform.tfvars` (gitignored); copy them from `terraform.tfvars.example`.

## License

MIT, see [LICENSE](LICENSE).
