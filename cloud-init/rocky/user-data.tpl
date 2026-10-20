#cloud-config
# cloud-init/rocky/user-data.tpl — rendered by scripts/make-seed.sh
# (the VM name and SSH public key placeholders are filled in per VM)
hostname: __VM_NAME__
manage_etc_hosts: true

users:
  - name: sysadmin
    groups: [wheel]
    shell: /bin/bash
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    ssh_authorized_keys:
      - __SSH_KEY__

ssh_pwauth: false

# Hyper-V integration services: the KVP daemon is what lets the host (and
# Terraform's wait_for_ips) read the guest's IP address.
package_update: true
packages:
  - hyperv-daemons

runcmd:
  - [systemctl, enable, --now, hypervkvpd.service]
