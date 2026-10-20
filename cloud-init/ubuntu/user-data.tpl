#cloud-config
# cloud-init/ubuntu/user-data.tpl — rendered by scripts/make-seed.sh
# (the VM name and SSH public key placeholders are filled in per VM)
hostname: __VM_NAME__
manage_etc_hosts: true

users:
  - name: sysadmin
    groups: [sudo]
    shell: /bin/bash
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    ssh_authorized_keys:
      - __SSH_KEY__

ssh_pwauth: false

# Hyper-V integration services: the KVP daemon is what lets the host (and
# Terraform's wait_for_ips) read the guest's IP address.
package_update: true
packages:
  - linux-cloud-tools-virtual

runcmd:
  # The cloud image's kernel can lag the metapackage: make sure the tools for the
  # running kernel are present.
  - [sh, -c, "apt-get install -y linux-cloud-tools-$(uname -r) || true"]
  # /dev/vmbus/hv_kvp existed before the package's udev rule did, so systemd never
  # tagged the device and the daemon's start would fail with "Dependency failed".
  # Replaying the add event applies the rule (and starts the daemon) without a reboot.
  - [udevadm, trigger, --subsystem-match=misc, --action=add]
  - [udevadm, settle]
  - [systemctl, enable, --now, hv-kvp-daemon.service]
