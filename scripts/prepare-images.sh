#!/usr/bin/env bash
# prepare-images.sh — download the Ubuntu 24.04 and Rocky 9 cloud images and
# convert them to VHDX for Hyper-V. Runs on the Linux control node.
#
#   scripts/prepare-images.sh [--cache DIR]      (default DIR: ~/iac-lab-images)
#
# Produces DIR/ubuntu-24.04-cloudimg-amd64.vhdx and DIR/rocky-9-cloudimg-amd64.vhdx
# (dynamic VHDX, 20 GB virtual size; cloud-init grows the root filesystem into it).
# Existing outputs are kept, so re-running is cheap.
# Needs: curl, qemu-img (apt install qemu-utils).
set -euo pipefail

CACHE="$HOME/iac-lab-images"
while [ $# -gt 0 ]; do
  case "$1" in
    --cache) CACHE="$2"; shift 2 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

UBUNTU_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
ROCKY_URL="https://dl.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2"
DISK_SIZE="20G"

command -v qemu-img >/dev/null || { echo "qemu-img not found: sudo apt install qemu-utils" >&2; exit 1; }
mkdir -p "$CACHE/seeds" "$CACHE/downloads"

fetch() { # url, output
  if [ -s "$2" ]; then echo "have     $(basename "$2")"; return; fi
  echo "download $(basename "$2")"
  curl -fL --progress-bar -o "$2.part" "$1" && mv "$2.part" "$2"
}

convert() { # source qcow2, output vhdx
  if [ -s "$2" ]; then echo "have     $(basename "$2")"; return; fi
  # qemu-img cannot resize a VHDX, so grow the (cached) qcow2 first: the VHDX
  # inherits the 20 GB virtual size and stays small on disk because it is dynamic.
  local cur; cur=$(qemu-img info --output=json "$1" | python3 -c 'import json,sys; print(json.load(sys.stdin)["virtual-size"])')
  if [ "$cur" -lt $((20 * 1024 * 1024 * 1024)) ]; then qemu-img resize -q "$1" "$DISK_SIZE"; fi
  echo "convert  $(basename "$2")"
  qemu-img convert -p -f qcow2 -O vhdx -o subformat=dynamic "$1" "$2.part"
  mv "$2.part" "$2"
}

fetch "$UBUNTU_URL" "$CACHE/downloads/noble-server-cloudimg-amd64.img"
fetch "$ROCKY_URL"  "$CACHE/downloads/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2"
convert "$CACHE/downloads/noble-server-cloudimg-amd64.img"                  "$CACHE/ubuntu-24.04-cloudimg-amd64.vhdx"
convert "$CACHE/downloads/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2"   "$CACHE/rocky-9-cloudimg-amd64.vhdx"

echo
ls -lh "$CACHE"/*.vhdx
echo "Next: scripts/make-seed.sh <vm-name> <ubuntu|rocky> ~/.ssh/lab_key.pub   (one seed per VM)"
