# iac-lab

A self-paced Infrastructure as Code lab: Terraform builds Linux VMs on a Hyper-V host, Ansible configures them, and HashiCorp Vault issues their secrets. This repo holds the runnable code; the guides that walk you through it live at <https://k13.io/lab/>. Start by forking this repo and cloning your fork onto a Linux control node, then follow the Terraform guide from its first module. It was written by a sysadmin learning these tools in a homelab, so treat it as a learning lab, not a production reference.

## Layout

| Path | What it holds |
|------|---------------|
| `terraform/environments/hyperv/` | Root module: provider, External switch, one file per lab VM, Ansible inventory output |
| `terraform/modules/hyperv-vm/` | Reusable module: copies a golden VHDX, attaches a cloud-init seed, waits for the IP |
| `cloud-init/` | NoCloud user-data and meta-data templates for the seed ISOs |
| `scripts/` | Host and control-node helpers (`setup-winrm.ps1`, image preparation, pushing images) |
| `ansible/` | Roles, playbooks, inventories and examples for the Ansible guide |
| `tests/` | Small shell and PowerShell checks the lab was verified with |

Example values in this repo use documentation addresses (`192.168.1.x`) and the hostname `hyperv-host`. Your own host, account and paths go in `terraform/environments/hyperv/terraform.tfvars` (gitignored); copy them from `terraform.tfvars.example`.

## License

MIT, see [LICENSE](LICENSE).
