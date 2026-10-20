#!/usr/bin/env bash
# push-images.sh — copy the prepared VHDX images and seed ISOs to the Hyper-V host over SSH.
#
#   scripts/push-images.sh <user>@<host> [--image-root 'C:\HyperV'] [--cache DIR] [--key FILE]
#   e.g. scripts/push-images.sh admin@hyperv-host --image-root 'D:\HyperV' --key ~/.ssh/id_ed25519
#
# Copies DIR/*.vhdx to <ImageRoot>\Images\ and DIR/seeds/*.iso to <ImageRoot>\Images\seeds\
# (the directories setup-winrm.ps1 created). A file whose size already matches on the
# host is skipped, so re-running after a new seed only sends the new seed.
# Needs OpenSSH Server on the host; Windows OpenSSH accepts forward slashes (D:/HyperV/Images).
set -euo pipefail

usage() { sed -n '2,10p' "$0" >&2; exit 2; }
[ $# -ge 1 ] || usage
TARGET="$1"; shift
IMAGE_ROOT='C:\HyperV'
CACHE="$HOME/iac-lab-images"
KEY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --image-root) IMAGE_ROOT="$2"; shift 2 ;;
    --cache)      CACHE="$2"; shift 2 ;;
    --key)        KEY="$2"; shift 2 ;;
    *) usage ;;
  esac
done
SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=10)
[ -n "$KEY" ] && SSH_OPTS+=(-i "$KEY")

# Windows path with backslashes → the forward-slash form scp understands (D:\HyperV → D:/HyperV)
root_fwd="${IMAGE_ROOT//\\//}"
root_fwd="${root_fwd%/}"

remote_size() { # Windows path → size in bytes, or empty. PowerShell is passed base64-encoded so quoting survives.
  local ps="(Get-Item '$1' -ErrorAction SilentlyContinue).Length"
  ssh "${SSH_OPTS[@]}" "$TARGET" powershell -NoProfile -NonInteractive -EncodedCommand \
    "$(printf '%s' "$ps" | iconv -f UTF-8 -t UTF-16LE | base64 -w0)" 2>/dev/null | tr -d '\r\n'
}

push() { # local file, remote subdirectory (Images or Images\seeds)
  local f="$1" sub="$2" name; name="$(basename "$f")"
  local win="$IMAGE_ROOT\\$sub\\$name"
  local have; have="$(remote_size "$win")"
  if [ "$have" = "$(stat -c %s "$f")" ]; then echo "have     $name"; return; fi
  echo "copy     $name ($(du -h "$f" | cut -f1))"
  scp -q "${SSH_OPTS[@]}" "$f" "$TARGET:$root_fwd/${sub//\\//}/$name"
}

shopt -s nullglob
vhdx=("$CACHE"/*.vhdx); isos=("$CACHE"/seeds/*.iso)
[ ${#vhdx[@]} -gt 0 ] || { echo "no .vhdx in $CACHE: run scripts/prepare-images.sh first" >&2; exit 1; }
[ ${#isos[@]} -gt 0 ] || { echo "no seeds in $CACHE/seeds: run scripts/make-seed.sh first" >&2; exit 1; }
for f in "${vhdx[@]}"; do push "$f" 'Images'; done
for f in "${isos[@]}"; do push "$f" 'Images\seeds'; done
echo "done: $IMAGE_ROOT\\Images on $TARGET holds ${#vhdx[@]} image(s) and ${#isos[@]} seed(s)"
