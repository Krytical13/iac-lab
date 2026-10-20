#!/usr/bin/env bash
# make-seed.sh — build a cloud-init NoCloud seed ISO for one lab VM.
#
#   scripts/make-seed.sh <vm-name> <ubuntu|rocky> <pubkey-file> [--out DIR]
#   e.g. scripts/make-seed.sh ubuntu-lab-01 ubuntu ~/.ssh/lab_key.pub
#
# Writes DIR/seeds/<vm-name>-seed.iso (default DIR: ~/iac-lab-images) with the
# volume id "cidata", which is how cloud-init recognises the seed on first boot.
# The guest gets the hostname <vm-name>, a passwordless-sudo user "sysadmin"
# that accepts the given public key, and the Hyper-V KVP daemon (so the host
# can read the VM's IP address). Needs: xorriso.
set -euo pipefail

usage() { sed -n '2,11p' "$0" >&2; exit 2; }
[ $# -ge 3 ] || usage
VM_NAME="$1"; OS="$2"; PUBKEY="$3"; shift 3
OUT="$HOME/iac-lab-images"
while [ $# -gt 0 ]; do
  case "$1" in
    --out) OUT="$2"; shift 2 ;;
    *) usage ;;
  esac
done

case "$OS" in ubuntu|rocky) ;; *) echo "os must be ubuntu or rocky" >&2; exit 2 ;; esac
[[ "$VM_NAME" =~ ^[a-z0-9][a-z0-9-]{0,62}$ ]] || { echo "vm-name must be a lowercase hostname" >&2; exit 2; }
[ -r "$PUBKEY" ] || { echo "cannot read public key $PUBKEY" >&2; exit 2; }
command -v xorriso >/dev/null || { echo "xorriso not found: sudo apt install xorriso" >&2; exit 1; }

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SSH_KEY="$(head -n1 "$PUBKEY")"

render() { # template file → stdout, with the two placeholders filled in
  local content; content="$(cat "$1")"
  content="${content//__VM_NAME__/$VM_NAME}"
  content="${content//__SSH_KEY__/$SSH_KEY}"
  printf '%s\n' "$content"
}

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
render "$REPO/cloud-init/$OS/user-data.tpl" > "$work/user-data"
render "$REPO/cloud-init/meta-data.tpl"     > "$work/meta-data"

mkdir -p "$OUT/seeds"
iso="$OUT/seeds/$VM_NAME-seed.iso"
xorriso -as mkisofs -quiet -o "$iso" -V cidata -J -R "$work/user-data" "$work/meta-data"
echo "wrote $iso ($(du -h "$iso" | cut -f1))"
